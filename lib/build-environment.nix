# Pure native environment composition. No filesystem discovery or setup hooks.
{ lib, base }:
let
  fail = message: throw "TVP environment: ${message}";
  unique = lib.unique;
  interface = p: p.development or { };
  expand =
    libraries:
    lib.unique (lib.concatMap (p: [ p ] ++ expand ((interface p).libraries or [ ])) libraries);
  directories =
    p:
    let
      d = interface p;
    in
    {
      includes =
        d.includes
          or (map (directory: "${lib.getDev p}/${directory}") (d.includeDirectories or [ "include" ]));
      libraries = d.libraryDirectories or [ "${lib.getLib p}/lib" ];
      pkgconfig =
        d.pkgconfig or [
          "${lib.getDev p}/lib/pkgconfig"
          "${lib.getDev p}/share/pkgconfig"
        ];
    };
  protected =
    key:
    builtins.match "[a-zA-Z_][a-zA-Z0-9_]*" key == null
    ||
      builtins.match "(BASH.*|SHELLOPTS|SHELL|ENV|IFS|PATH|CDPATH|GLOBIGNORE|POSIXLY_CORRECT|TVP_.*|LD_.*)" key
      != null
    || (
      lib.hasPrefix "NIX_" key
      && !(builtins.elem key [
        "NIX_CFLAGS_COMPILE"
        "NIX_CFLAGS_LINK"
        "NIX_LDFLAGS"
      ])
    )
    || builtins.elem key [
      "out"
      "outputs"
      "HOME"
      "TMPDIR"
      "PWD"
      "OLDPWD"
      "SHLVL"
      "buildInputs"
      "nativeBuildInputs"
      "initialPath"
      "noDumpEnvVars"
      "preHook"
      "postHook"
    ];
  encode =
    key: args:
    if
      !(builtins.elem key [
        "NIX_CFLAGS_COMPILE"
        "NIX_CFLAGS_LINK"
        "NIX_LDFLAGS"
      ])
    then
      fail "${key}: no owned flag encoder; use the tool's explicit scalar protocol"
    else if
      !builtins.isList args
      || !builtins.all (
        a:
        builtins.isString a
        && a != ""
        && builtins.match ".*[[:space:]].*" a == null
        && (key != "NIX_LDFLAGS" || !lib.hasInfix "," a)
      ) args
    then
      fail "${key}: unsupported argument encoding (expected nonempty whitespace-free arguments)"
    else
      lib.concatStringsSep " " args;
in
{
  tools ? [ ],
  libraries ? [ ],
  overrides ? { },
}:
let
  resolved = expand libraries;
  cc = base.stdenv.cc;
  baseline = {
    values = {
      CC = "${cc}/bin/cc";
      CXX = "${cc}/bin/c++";
      AR = "${cc.bintools}/bin/ar";
      AS = "${cc.bintools}/bin/as";
      LD = "${cc.bintools}/bin/ld";
      NM = "${cc.bintools}/bin/nm";
      RANLIB = "${cc.bintools}/bin/ranlib";
      STRIP = "${cc.bintools}/bin/strip";
      READELF = "${cc.bintools}/bin/readelf";
      OBJCOPY = "${cc.bintools}/bin/objcopy";
      LC_ALL = "C";
      TZ = "UTC";
    };
    flags = {
      NIX_CFLAGS_COMPILE = lib.concatMap (
        p:
        lib.concatMap (d: [
          "-isystem"
          d
        ]) (directories p).includes
      ) resolved;
      NIX_LDFLAGS = lib.concatMap (
        p:
        lib.concatMap (d: [
          "-L${d}"
          "-rpath"
          d
        ]) (directories p).libraries
      ) resolved;
    };
  };
  contributions =
    [
      {
        origin = "base ${base.name}";
        data = baseline;
      }
    ]
    ++ map (tool: {
      origin = "tool ${tool.name or (toString tool)}";
      data =
        if tool ? buildEnvironment then
          tool.buildEnvironment {
            inherit tool;
            libraries = resolved;
            inherit directories;
          }
        else
          { };
    }) tools;
  entries =
    origin: data:
    lib.concatMap
      (
        kind:
        map (key: {
          inherit origin kind key;
          value = data.${kind}.${key};
        }) (builtins.attrNames (data.${kind} or { }))
      )
      [
        "values"
        "paths"
        "flags"
      ];
  replacements = entries "recipe overrides" overrides;
  replaced = map (e: e.key) replacements;
  all =
    lib.concatMap (
      c: builtins.filter (e: !(builtins.elem e.key replaced)) (entries c.origin c.data)
    ) contributions
    ++ replacements;
  merged = builtins.foldl' (
    acc: e:
    let
      old = acc.${e.key} or null;
      conflict = fail "${e.key}: conflict between ${old.origin} (${old.kind}) and ${e.origin} (${e.kind})";
      checked =
        if protected e.key then
          fail "protected variable ${e.key} from ${e.origin}"
        else if e.kind == "values" && !builtins.isString e.value then
          fail "${e.key}: scalar from ${e.origin} must be a string"
        else if
          e.kind == "flags" && (!builtins.isList e.value || !builtins.all builtins.isString e.value)
        then
          fail "${e.key}: flags from ${e.origin} must be strings"
        else if
          e.kind == "paths"
          && (
            !builtins.isAttrs e.value
            || !(e.value ? separator)
            || !(e.value ? entries)
            || !builtins.isString e.value.separator
            || e.value.separator == ""
            || !builtins.isList e.value.entries
            || !builtins.all (
              p: builtins.isString p && p != "" && !lib.hasInfix e.value.separator p
            ) e.value.entries
          )
        then
          fail "${e.key}: invalid paths from ${e.origin}"
        else
          e;
    in
    builtins.seq checked (
      acc
      // {
        ${e.key} =
          if old == null then
            e
          else if old.kind != e.kind then
            conflict
          else if e.kind == "values" then
            if old.value == e.value then old else conflict
          else if e.kind == "flags" then
            old // { value = old.value ++ e.value; }
          else if old.value.separator != e.value.separator then
            conflict
          else
            old
            // {
              value = old.value // {
                entries = old.value.entries ++ e.value.entries;
              };
            };
      }
    )
  ) { } all;
  env = lib.mapAttrs (
    key: e:
    if e.kind == "values" then
      e.value
    else if e.kind == "flags" then
      encode key e.value
    else
      lib.concatStringsSep e.value.separator (unique e.value.entries)
  ) merged;
in
{
  tools =
    tools
    ++ [
      cc
      cc.bintools
      (lib.getBin cc.libc)
    ]
    ++ base.stdenv.initialPath;
  libraries = resolved;
  inherit env;
  # Structured data remains inspectable until the adapter renders it.
  environmentContributions = merged;
}

# Differential specification edits; no marker provider may ever be realized.
{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  plain = builtins.unsafeDiscardStringContext;
  marker = builtins.derivation {
    name = "effective-input-never-build";
    system = "x86_64-linux";
    builder = "/never-build";
  };
  replacement =
    provider:
    provider
    // {
      outPath = marker.outPath;
      drvPath = marker.drvPath;
    }
    //
      lib.genAttrs
        (builtins.filter (name: provider ? ${name}) (
          lib.unique (
            (provider.outputs or [ ])
            ++ [
              "out"
              "bin"
              "dev"
              "lib"
            ]
          )
        ))
        (
          name:
          (if builtins.isAttrs provider.${name} then provider.${name} else { })
          // {
            outPath = marker.outPath;
            drvPath = marker.drvPath;
          }
        );
  set =
    path: value: attrs:
    let
      name = builtins.head path;
      rest = builtins.tail path;
    in
    attrs // { ${name} = if rest == [ ] then value else set rest value attrs.${name}; };
  commands =
    p:
    let
      s = p.specification;
    in
    lib.concatStringsSep "\n" (
      map (step: step.run or "") p.buildSteps
      ++ map (step: step.run or "") (
        let
          plan = s.upstreamPlan or [ ];
        in
        if builtins.isFunction plan then plan p.artifact else plan
      )
      ++ [
        (s.upstreamCheck.run or "")
        (s.upstreamCheck.command.run or "")
      ]
    );
  cases = {
    mpfr = [
      "canonical.mpfr_4_2_2"
      "gmp"
    ];
    mpc = [
      "canonical.mpc_1_4_1"
      "mpfr"
    ];
    gmp = [
      "canonical.gmp_6_3_0"
      "bash"
    ];
    json-c = [
      "canonical.json-c_0_19"
      "bash"
    ];
    zstd = [
      "canonical.zstd_1_5_7"
      "zlib"
    ];
    acl = [
      "canonical.acl_2_4_0"
      "bash"
    ];
    attr = [
      "canonical.attr_2_6_0"
      "bash"
    ];
    libxcrypt = [
      "canonical.libxcrypt_4_5_2"
      "bash"
    ];
    libxml2 = [
      "canonical.libxml2_2_15_4"
      "bash"
    ];
    xz = [
      "canonical.xz_5_8_4"
      "bash"
    ];
    nghttp2 = [
      "canonical.nghttp2_1_70_0"
      "bash"
    ];
    pcre2 = [
      "canonical.pcre2_10_49"
      "coreutils"
    ];
    sqlite = [
      "canonical.sqlite_3_53_4"
      "coreutils"
    ];
    bzip2 = [
      "canonical.bzip2_1_0_8"
      "bash"
    ];
    patchelf = [
      "canonical.patchelf_0_19_2"
      "bash"
    ];
    gn = [
      "canonical.gn_20260707"
      "python"
    ];
    gradle = [
      "canonical.gradle_9_3_1"
      "helperPython"
    ];
    gzip = [
      "canonical.gzip_1_15"
      "coreutils"
    ];
    texinfo = [
      "canonical.texinfo_7_1"
      "coreutils"
    ];
    expat = [
      "canonical.expat_2_9_0"
      "tools"
      "python"
    ];
    isl = [
      "canonical.isl_0_28"
      "libraries"
      "gmp"
    ];
    libyaml = [
      "canonical.libyaml_0_2_5"
      "tools"
      "python"
    ];
    linux-headers = [
      "canonical.linux-headers_6_9"
      "tools"
      "gnumake"
    ];
    gettext = [
      "canonical.gettext_1_0"
      "providers"
      "ncurses"
    ];
    gettext-perl = [
      "canonical.gettext_1_0"
      "runtime"
      "perl"
    ];
    gettext-jdk = [
      "canonical.gettext_1_0"
      "runtime"
      "jdk"
    ];
    variant-json-c = [
      "variants.build-steps.json-c_0_19"
      "bash"
    ];
    variant-zstd = [
      "variants.build-steps.zstd_1_5_7"
      "zlib"
    ];
  };
  at = id: lib.attrByPath (lib.splitString "." id) null tvp;
  providers = lib.mapAttrs (
    _: entry:
    let
      p = at (builtins.head entry);
      path = builtins.tail entry;
      name = lib.last path;
      selected = replacement (lib.attrByPath path null p.specification);
      edited = p.edit (set path selected);
    in
    {
      metadata = edited.tvp.deps.${name}.outPath == selected.outPath;
      command = lib.hasInfix (plain marker.outPath) (plain (commands edited));
      noStaleCommand =
        !(lib.hasInfix (plain (toString (lib.attrByPath path null p.specification))) (
          plain (commands edited)
        ));
    }
  ) cases;
  checks =
    lib.genAttrs
      [
        "mpfr_4_2_1"
        "mpfr_4_2_2"
        "mpc_1_4_1"
        "gmp_6_3_0"
        "json-c_0_19"
        "zstd_1_5_7"
        "expat_2_9_0"
        "isl_0_28"
        "libyaml_0_2_5"
        "patchelf_0_19_2"
        "curl_8_23_0"
      ]
      (
        name:
        let
          p = tvp.canonical.${name};
          q = p.edit (s: s // { doCheck = false; });
          matching = builtins.filter (step: lib.hasSuffix ".check" step.name) q.buildSteps;
          disabled =
            if q.specification ? upstreamCheck then
              !(q.specification.upstreamCheck.enabled or true)
            else
              matching != [ ] && builtins.all (step: !(step.enabled or true)) matching;
        in
        disabled && !(q.specification.tvp.features.doCheck or false)
      );
  shells =
    lib.genAttrs
      [
        "python-build_3_12_5"
        "python-minimal_3_12_5"
        "cmake_4_4_5"
        "gnumake_4_4_1"
        "m4_1_4_21"
        "meson_1_12_1"
        "ninja_1_13_2"
        "bzip2_1_0_8"
        "gradle_9_3_1"
      ]
      (
        name:
        let
          p = tvp.canonical.${name};
          selected = replacement p.specification.bash;
          q = p.edit (s: s // { bash = selected; });
          r = p.editRuntime (runtime: runtime // { shell = selected; });
        in
        q.runtime.shell.outPath == selected.outPath
        && r.artifact.drvPath == p.artifact.drvPath
        && r.drvPath != p.drvPath
        && lib.hasInfix (plain marker.outPath) (plain (commands r))
      );
  model =
    functional: dependency:
    let
      specification = dependency: {
        pname = "effective-input-model";
        version = "1";
        src = null;
        base = tvp.canonical.mpfr_4_2_2.specification.base;
        inherit (tvp.canonical.mpfr_4_2_2.specification) bash coreutils;
        plan = [
          {
            name = "model.command";
            run = "printf '%s' ${dependency} > \"$out\"";
          }
        ];
      };
    in
    tvp.builder {
      recipe =
        if functional then
          ({ dependency }: final: specification dependency)
        else
          ({ dependency }: specification dependency);
      args = {
        inherit dependency;
      };
      dependencyNames = [ "dependency" ];
      metadata = { };
      selection.kind = "fixture";
      mkTests = _: { };
    };
  original = tvp.canonical.gmp_6_3_0;
  fixture = model true original;
  unknownField = fixture.edit (s: s // { dependency = marker; });
  direct = model false original;
  directUnknownField = direct.edit (s: s // { dependency = marker; });
  explicit = fixture.edit (
    s:
    s
    // {
      dependencyProviders.dependency = marker;
      plan = [
        {
          name = "model.command";
          run = "printf '%s' ${marker} > \"$out\"";
        }
      ];
    }
  );
  contracts = {
    inherit providers checks shells;
    unpublishedFieldDoesNotLie =
      unknownField.tvp.deps.dependency.outPath == original.outPath
      && unknownField.drvPath == fixture.drvPath;
    directUnpublishedFieldDoesNotLie =
      directUnknownField.tvp.deps.dependency.outPath == original.outPath
      && directUnknownField.drvPath == direct.drvPath;
    explicitProjection =
      explicit.tvp.deps.dependency.outPath == marker.outPath
      && lib.hasInfix (plain marker.outPath) (plain (commands explicit));
  };
  failures =
    prefix: value:
    if builtins.isBool value then
      lib.optional (!value) prefix
    else
      lib.concatMap (name: failures "${prefix}.${name}" value.${name}) (builtins.attrNames value);
  failed = failures "contracts" contracts;
in
assert failed == [ ] || throw "Effective input contracts: ${lib.concatStringsSep ", " failed}";
contracts

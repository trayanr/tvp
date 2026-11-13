# Construction contexts contain provider generations, not package constructors.
{ lib, builder }:
let
  fail = message: throw "TVP base tier: ${message}";
  platform = {
    system = "x86_64-linux";
    config = "x86_64-unknown-linux-gnu";
    isMusl = false;
  };
  package = value: builtins.isAttrs value && value ? outPath;
  named = value: value.pname or (builtins.parseDrvName value.name).name;
  select =
    names: values: builtins.filter (value: package value && builtins.elem (named value) names) values;
  floorRoles = {
    gnumake = [
      "gnumake"
      "make"
    ];
    gnutar = [
      "gnutar"
      "tar"
    ];
    xz = [ "xz" ];
    gzip = [ "gzip" ];
    bzip2 = [ "bzip2" ];
    sed = [
      "gnused"
      "sed"
    ];
    grep = [
      "gnugrep"
      "grep"
    ];
    gawk = [ "gawk" ];
    diffutils = [ "diffutils" ];
    findutils = [ "findutils" ];
    patch = [
      "patch"
      "gnupatch"
    ];
    file = [ "file" ];
  };
  fromFloor =
    values:
    builtins.listToAttrs (
      lib.concatMap (
        role:
        let
          matches = select floorRoles.${role} values;
        in
        lib.optional (matches != [ ]) {
          name = role;
          value = builtins.head matches;
        }
      ) (builtins.attrNames floorRoles)
    );
in
rec {
  mkTier =
    {
      name,
      previous ? null,
      compiler,
      shell,
      coreutils,
      standardTools ? { },
      tools ? [ ],
      referencePackages ? [ ],
    }:
    builder.base {
      inherit
        name
        platform
        compiler
        shell
        coreutils
        standardTools
        referencePackages
        ;
      tools = lib.unique ([ coreutils ] ++ tools);
      construction = {
        kind = if previous == null then "seed" else "stage";
        previous = if previous == null then null else previous.name;
      };
    };

  # Keep the exact selected compiler, libc and floor. This adapts their interface;
  # it does not rebuild them or claim that their recipes use the owned protocol.
  fromLegacy =
    legacy:
    if legacy ? compiler && !(legacy ? stdenv) then
      legacy
    else if !(legacy ? stdenv && legacy ? name) then
      fail "expected a named construction base with a selected stdenv"
    else
      let
        inherit (legacy) stdenv;
        selectedPlatform = legacy.platform or platform;
        floor = stdenv.initialPath;
        shells = select [
          "bash"
          "bashNonInteractive"
        ] floor;
        coreTools = select [ "coreutils" ] floor;
        fixups = select [ "patchelf" ] (stdenv.defaultNativeBuildInputs or [ ]);
        selectedCompiler = stdenv.cc;
        rawCompiler = selectedCompiler.cc or selectedCompiler;
        compiler = selectedCompiler // {
          runtimeDirectories =
            selectedCompiler.runtimeDirectories or (lib.unique [
              "${lib.getLib selectedCompiler.libc}/lib"
              "${lib.getLib rawCompiler}/lib"
            ]);
          defaultHardeningFlags = selectedCompiler.defaultHardeningFlags or [ ];
          libcTools = selectedCompiler.libcTools or [ (lib.getBin selectedCompiler.libc) ];
        };
        patchelf =
          if legacy ? fixupTools && legacy.fixupTools ? patchelf then
            legacy.fixupTools.patchelf
          else if fixups != [ ] then
            builtins.head fixups
          else
            null;
      in
      if shells == [ ] || coreTools == [ ] then
        fail "construction floor must name Bash and Coreutils packages"
      else
        builder.base {
          name = "${legacy.name}-inputs";
          platform = selectedPlatform // {
            isMusl = selectedPlatform.isMusl or (selectedPlatform.hostPlatform.isMusl or false);
          };
          inherit compiler;
          shell = stdenv.shellPackage or (builtins.head shells);
          coreutils = builtins.head coreTools;
          tools = floor;
          standardTools = fromFloor floor // lib.optionalAttrs (patchelf != null) { inherit patchelf; };
          referencePackages = [
            selectedCompiler
            selectedCompiler.bintools
            selectedCompiler.libc
            rawCompiler
          ] ++ (legacy.runtimeInputs or [ ]);
          construction = {
            kind = "legacy-inputs";
            previous = legacy.builtBy or null;
            sourceBase = legacy.name;
          };
        };
}

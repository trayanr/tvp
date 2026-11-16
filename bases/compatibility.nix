# Execute remaining stdenv recipes with an actual source-owned compiler/tool set.
# The compatibility surface is a local constructor, not a borrowed environment.
{
  lib,
  config,
  builder,
  platform,
  name,
  base,
  builtBy ? null,
  tvpLib ? import ../lib { inherit lib; },
}:
let
  native = lib.systems.elaborate platform.system;
  selectedPlatform =
    (tvpLib.platforms.mkNative {
      buildPlatform = native;
      hostPlatform = native;
      targetPlatform = native;
    })
    // {
      isMusl = platform.isMusl or false;
    };
  # This source-built File is an explicit construction role. It is not selected
  # through public aliases which may depend on the compiler being constructed.
  file = base.tools.file or (import ../bootstrap/source-full-gcc.nix { }).file;
  originalCompiler = base.compiler;
  originalBinutils = originalCompiler.bintools;
  binutils = originalBinutils // {
    bintools = originalBinutils;
  };
  compiler =
    originalCompiler
    // {
      bintools = binutils;
      targetPrefix = originalCompiler.targetPrefix or "";
      isGNU = true;
    }
    // lib.optionalAttrs (originalCompiler ? cc || originalCompiler ? tvp.deps.compiler) {
      cc = originalCompiler.cc or originalCompiler.tvp.deps.compiler;
    };
  tools = base.tools // {
    inherit file;
    gcc = compiler;
    binutils = binutils;
  };
  floor = with tools; [
    coreutils
    findutils
    diffutils
    sed
    grep
    gawk
    gnutar
    gzip
    bzip2
    gnumake
    bash
    patch
    xz
    file
  ];
  owned = base.override {
    platform = selectedPlatform;
    tools = {
      gcc = compiler;
      inherit binutils file;
    };
    baselineTools = floor;
  };
  libcPaths = lib.concatMapStringsSep "\n" (
    package: "addToSearchPath _PATH ${lib.getBin package}/bin"
  ) (compiler.libcTools or [ ]);
  compilerHook =
    lib.replaceStrings
      [
        "@bintools@"
        "addToSearchPath _PATH @libcBin@/bin"
        "@out@"
        ": \"\${NIX_HARDENING_ENABLE=bindnow fortify format pic relro stackprotector strictoverflow}\""
      ]
      [
        (toString binutils)
        libcPaths
        (toString compiler)
        ": \"\${NIX_HARDENING_ENABLE=}\""
      ]
      (builtins.readFile ./wrappers/cc-setup.sh);
  linkerHook = lib.replaceStrings [ "@out@" ] [ (toString binutils) ] (
    builtins.readFile ./wrappers/bintools-setup.sh
  );
  setupHook = builder {
    recipe =
      { }:
      _: {
        pname = "tvp-${name}-compiler-setup";
        version = compiler.version;
        src = null;
        base = owned;
        bash = tools.bash;
        coreutils = tools.coreutils;
        plan = [
          {
            name = "compatibility.setup";
            tools = [ tools.coreutils ];
            run = ''
              cat > "$out" <<'TVP_COMPILER_SETUP'
              ${compilerHook}
              ${linkerHook}
              export CC=${compiler}/bin/cc CXX=${compiler}/bin/c++
              export AR=${binutils}/bin/ar AS=${binutils}/bin/as LD=${binutils}/bin/ld
              export NM=${binutils}/bin/nm RANLIB=${binutils}/bin/ranlib STRIP=${binutils}/bin/strip
              TVP_COMPILER_SETUP
            '';
          }
        ];
      };
    args = { };
    dependencyNames = [ ];
    metadata.kind = "source-compiler-compatibility";
    selection.kind = "source-compiler-compatibility";
    mkTests = _: { };
  };
  stdenv =
    (import ./stdenv {
      inherit lib config;
      platform = selectedPlatform;
    })
      {
        name = "tvp-${name}-stdenv";
        cc = compiler;
        initialPath = floor;
        shell = "${tools.bash}/bin/bash";
        fixupInputs = [ setupHook ];
      };
in
assert selectedPlatform.config == platform.config;
tvpLib.bases.legacyEnvironment {
  inherit name stdenv builtBy;
  base = owned;
}

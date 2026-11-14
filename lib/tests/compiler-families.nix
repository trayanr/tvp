# Owner-run source/identity contracts only; never realize these marker packages.
{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  modules = {
    gcc = import ../../pkgs/compilers/gcc { inherit pkgs tvp; };
    llvm = import ../../pkgs/compilers/llvm { inherit pkgs tvp; };
    go = import ../../pkgs/compilers/go { inherit pkgs tvp; };
    go-bootstrap = import ../../pkgs/compilers/go-bootstrap { inherit pkgs tvp; };
    rustc = import ../../pkgs/compilers/rust { inherit pkgs tvp; };
  };
  expected = {
    gcc = 2;
    llvm = 1;
    go = 5;
    go-bootstrap = 1;
    rustc = 1;
  };
  full = tvp.baseTiers.full;
  selected = lib.foldl' (all: family: all // modules.${family}.canonical) { } (
    builtins.attrNames modules
  );
  row =
    p:
    let
      s = p.specification;
      parts = tvp.builder.steps.partition p.buildSteps;
      finalOnly = p.editSteps (
        plan:
        plan
        ++ [
          {
            name = "compiler.final-control";
            run = ": compiler-final-control";
          }
        ]
      );
      runtime = p.editRuntime (r: r // { control = "runtime-only"; });
      # Source-only marker code is intentionally invalid and must never build.
      source = p.override { src = builtins.toFile "compiler-source-control" "never build this"; };
      registered = builtins.attrNames p.tests;
    in
    {
      sourceOwnedConstructor = !(p ? overrideAttrs);
      split = parts.split && parts.first != [ ] && parts.second != [ ];
      oneSplit = builtins.length (builtins.filter (step: (step.kind or "") == "split") p.buildSteps) == 1;
      explicitClosedHostCompiler = s.base.compiler.drvPath == full.compiler.drvPath;
      noPublicCompilerBootstrap = s.base.compiler.drvPath != tvp.canonical.gcc_16_2_0.drvPath;
      sourceInvalidatesA = source.artifact.drvPath != p.artifact.drvPath;
      noOpOverride = (p.override { }).drvPath == p.drvPath;
      noOpEdit = (p.edit (x: x)).drvPath == p.drvPath;
      finalEditReusesA =
        finalOnly.artifact.drvPath == p.artifact.drvPath && finalOnly.drvPath != p.drvPath;
      runtimeMetadataDoesNotRebuildA = runtime.artifact.drvPath == p.artifact.drvPath;
      installedVersionTest = builtins.elem "version" registered;
      testsRebound = finalOnly.tests.version.package.drvPath == finalOnly.drvPath;
    };
  rows = lib.mapAttrs (_: row) selected;
  names = {
    gcc = [
      "13.3.0"
      "16.2.0"
    ];
    llvm = [ "23.1.4" ];
    go = [
      "1.17.13"
      "1.20.14"
      "1.22.12"
      "1.24.13"
      "1.27.3"
    ];
    go-bootstrap = [ "20171003" ];
    rustc = [ "1.97.1" ];
  };
  perFamily = lib.mapAttrs (
    family: versions:
    let
      m = modules.${family};
      recipe = m.recipes.${family};
      counts = builtins.length (builtins.attrNames recipe.versionTable) == expected.${family};
      definitionBases = builtins.all (v: recipe.versionTable.${v}.def ? base) versions;
      # Requires the separate instantiate-definition-base additive patch.
      instantiateKeepsRoles = builtins.all (
        v:
        let
          canonical = m.canonical.${tvp.lib.versions.attrName family v};
          chosen = m.instantiate { version = v; };
        in
        chosen.drvPath == canonical.drvPath && chosen.artifact.drvPath == canonical.artifact.drvPath
      ) versions;
      explicitCallerBase =
        let
          chosen = m.instantiate {
            version = builtins.head versions;
            base = full.override { name = "compiler-explicit-base-control"; };
          };
        in
        chosen.specification.base.name == "compiler-explicit-base-control";
    in
    {
      inherit
        counts
        definitionBases
        instantiateKeepsRoles
        explicitCallerBase
        ;
    }
  ) names;
  gcc = modules.gcc.canonical;
  go = modules.go.canonical;
  llvm = modules.llvm.canonical.llvm_23_1_4;
  rust = modules.rustc.canonical.rustc_1_97_1;
  seed = modules.go-bootstrap.canonical.go-bootstrap_20171003;
  targetProviderControl =
    p:
    let
      marker = p.specification.binutils // {
        outPath = "/nix/store/00000000000000000000000000000000-target-binutils-control";
      };
      q = p.override { binutils = marker; };
      configure = builtins.head (builtins.filter (step: step.name == "gcc.configure") q.buildSteps);
    in
    lib.hasInfix "AR_FOR_TARGET=\"${marker}/bin/ar\"" configure.run
    && lib.hasInfix "CC_FOR_BUILD=\"$CC\"" configure.run
    && builtins.elem "--with-as=${marker}/bin/as" q.specification.configureFlags
    && builtins.elem "--with-ld=${marker}/bin/ld" q.specification.configureFlags
    && q.specification.base.compiler.drvPath == p.specification.base.compiler.drvPath;
  strict = {
    gcc13OriginalTargetLibc =
      gcc.gcc_13_3_0.specification.glibc.drvPath == tvp.bases.default.stdenv.cc.libc.drvPath;
    gcc16ClosedTargetLibc = gcc.gcc_16_2_0.specification.glibc.drvPath == full.compiler.libc.drvPath;
    mandatoryBootstrapComparison =
      builtins.all
        (
          p:
          lib.hasInfix "compare"
            (builtins.head (builtins.filter (step: step.name == "gcc.bootstrap") p.buildSteps)).run
        )
        [
          gcc.gcc_13_3_0
          gcc.gcc_16_2_0
        ];
    ordinaryGcc13TargetRoles = targetProviderControl gcc.gcc_13_3_0;
    ordinaryGcc16TargetRoles = targetProviderControl gcc.gcc_16_2_0;
    mandatoryGccUpstream =
      gcc.gcc_13_3_0.tests ? upstream-audit && gcc.gcc_16_2_0.tests ? upstream-audit;
    gccRawExecutionShared =
      builtins.all (p: p.validation.drvPath == p.tests.upstream-audit.package.drvPath)
        [
          gcc.gcc_13_3_0
          gcc.gcc_16_2_0
        ];
    oldGoRawExecutionShared =
      builtins.all (p: p.validation.drvPath == p.tests.upstream-audit.package.drvPath)
        [
          go.go_1_17_13
          go.go_1_20_14
          go.go_1_22_12
          go.go_1_24_13
        ];
    oldGoSeedExact =
      go.go_1_17_13.specification.bootstrap.drvPath
      == (import ../../pkgs/compilers/go-bootstrap/legacy.nix { inherit pkgs tvp; })
      .canonical.go-bootstrap_20171003.drvPath;
    latestGoSeedExact =
      go.go_1_27_3.specification.bootstrap.drvPath == modules.go.construction.go_1_24_13.drvPath;
    movingOldGoLadder = go.go_1_24_13.specification.bootstrap.drvPath == go.go_1_22_12.drvPath;
    llvmHostAndTargetSeparate =
      llvm.specification.base.compiler.drvPath != llvm.specification.rawGCC.drvPath;
    llvmTargetRuntimesMatch =
      llvm.specification.rawGCC.drvPath == llvm.specification.gccRuntime.drvPath
      && llvm.specification.rawGCC.drvPath == llvm.specification.cxxRuntime.drvPath;
    llvmProfilePreserved = builtins.all (flag: builtins.elem flag llvm.specification.cmakeFlags) [
      "-DLLVM_TARGETS_TO_BUILD=all"
      "-DLLVM_ENABLE_ZLIB=FORCE_ON"
      "-DLLVM_ENABLE_ZSTD=FORCE_ON"
      "-DLLVM_ENABLE_LIBXML2=FORCE_ON"
      "-DLLVM_ENABLE_FFI=FORCE_ON"
    ];
    seedRemainsCSource =
      seed.specification.cgo == false && seed.specification.compiler.drvPath == full.compiler.drvPath;
    binaryRustStillRecorded = modules.rustc.recipes.rustc.versionTable."1.97.1".def ? blob;
    rustTargetByteControl = rust.tests ? target-bytes;
  };
  all = builtins.all (x: x) (
    (lib.concatMap builtins.attrValues (builtins.attrValues rows))
    ++ (lib.concatMap builtins.attrValues (builtins.attrValues perFamily))
    ++ builtins.attrValues strict
  );
in
{
  inherit rows perFamily strict;
  success = all;
}

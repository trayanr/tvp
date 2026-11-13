# MPFR is the first family using tier-local instantiation and implicit base tools.
# These compare evaluated plans; they never realize a package or model provider.
{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  bootstrap = import ../../bootstrap { };
  family = import ../../pkgs/libraries/mpfr { inherit tvp; };
  instantiate =
    version:
    family.instantiate {
      inherit version;
      base = tvp.baseTiers.seed;
      deps.gmp = bootstrap.gnu-gmp;
    };
  p = instantiate "4.2.2";
  withoutCheck = p.override { doCheck = false; };
  checkFlags = p.override { checkCFlags = [ "-std=gnu17" ]; };
  stripped = p.override { stripFlags = [ "--strip-debug" ]; };
  runtime = p.editRuntime (r: r // { dlopenDirectories = [ "/mpfr-runtime-probe" ]; });
  marker = builtins.derivation {
    name = "mpfr-tool-never-build";
    system = "x86_64-linux";
    builder = "/never-build-mpfr-tool";
  };
  edited = p.edit (
    s:
    s
    // {
      base = s.base.edit (
        b:
        b
        // {
          standardTools = b.standardTools // {
            gnumake = marker;
          };
        }
      );
    }
  );
  makeStep = builtins.head (builtins.filter (s: s.name == "mpfr.build") edited.buildSteps);
  nativeInputs = import ../../bootstrap/source-native-compiler.nix { };
  fullInputs = import ../../bootstrap/source-full-gcc.nix { };
  sameProduction = q: q.artifact.drvPath == p.artifact.drvPath && q.drvPath == p.drvPath;
  results = {
    allVersionsUseOneOwnedProcedure = builtins.all (
      version:
      let
        q = family.canonical.${"mpfr_" + lib.replaceStrings [ "." ] [ "_" ] version};
      in
      q.specification.base.name == tvp.baseTiers.full.name
      && builtins.length (builtins.filter (s: (s.kind or "") == "split") q.buildSteps) == 1
      && !(q ? overrideAttrs)
      && q.tvp.deps.gmp.drvPath == family.recipes.mpfr.versionTable.${version}.def.deps.gmp.drvPath
    ) (builtins.attrNames family.recipes.mpfr.versionTable);
    noopOverride = sameProduction (p.override { });
    noopEdit = sameProduction (p.edit (s: s));
    testPolicyReusesProduction = sameProduction withoutCheck && !(withoutCheck.tests ? upstream);
    testFlagsReuseProduction =
      sameProduction checkFlags && checkFlags.tests.upstream.drvPath != p.tests.upstream.drvPath;
    stripReusesArtifact =
      stripped.artifact.drvPath == p.artifact.drvPath && stripped.drvPath != p.drvPath;
    runtimeReusesArtifact =
      runtime.artifact.drvPath == p.artifact.drvPath && runtime.drvPath != p.drvPath;
    baseEditRebindsCommand = lib.hasInfix (builtins.unsafeDiscardStringContext "${marker}/bin/make") makeStep.run;
    baseEditRebindsMetadata = edited.tvp.deps.gnumake.drvPath == marker.drvPath;
    upstreamIsIndependent =
      !(builtins.any (s: s.name == "mpfr.check") p.buildSteps)
      && p.tests.upstream.specification.validation.production.drvPath == p.artifact.drvPath;
    targetIsActualNativeInput =
      tvp.baseTiers.target.compiler.drvPath == nativeInputs.prior.composition.cc.drvPath;
    nativeLineage =
      tvp.baseTiers.native.construction.previous == tvp.baseTiers.target.name
      && tvp.baseTiers.native.compiler.drvPath == nativeInputs.driver.drvPath;
    fullLineage =
      tvp.baseTiers.full.construction.previous == tvp.baseTiers.native.name
      && tvp.baseTiers.native.compiler.drvPath == fullInputs.native.composition.cc.drvPath;
  };
  failed = builtins.filter (name: !results.${name}) (builtins.attrNames results);
in
assert failed == [ ] || throw "MPFR family contracts: ${lib.concatStringsSep ", " failed}";
results

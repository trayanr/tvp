# Model providers are never realized. Legacy execution inputs deliberately throw.
{ lib, builder }:
let
  tvpLib = import ../default.nix { inherit lib; };
  package =
    pname: version:
    let
      output = builtins.derivation {
        name = "base-suite-model-${pname}-${version}";
        system = "x86_64-linux";
        builder = "/never-build-a-base-suite-model";
      };
    in
    output
    // {
      inherit pname version;
      bin = output;
    };
  bash = package "bash" "5";
  coreutils = package "coreutils" "9";
  binutils = package "binutils" "2.42";
  libc = package "glibc" "2.39";
  compiler = (package "gcc-wrapper" "13.3.0") // {
    bintools = binutils;
    inherit libc;
    runtimeDirectories = [ "${libc}/lib" ];
    defaultHardeningFlags = [ ];
  };
  owned = builder.base {
    name = "base-suite-model";
    platform = {
      system = "x86_64-linux";
      config = "x86_64-unknown-linux-gnu";
      isMusl = false;
    };
    tools = {
      gcc = compiler;
      inherit bash coreutils;
    };
  };
  base = {
    name = "retained-base-suite-model";
    ownedBase = owned;
    cc = throw "shared checks must read the selected compiler";
    binutils = throw "shared checks must read the selected Binutils";
    libc = throw "shared checks must read the selected libc";
    stdenv = throw "shared base checks must not execute through stdenv";
    platform = throw "shared base checks must use owned platform facts";
  };
  suiteFor =
    base:
    import ../../bases/tests {
      inherit base tvpLib;
      pkgs = { inherit lib; };
    };
  suite = suiteFor base;
  names = [
    "binutils-version"
    "cc-version"
    "compile"
    "cxx"
    "floor"
    "libc-version"
    "response-file"
    "static"
  ];
  leaves = builtins.attrValues suite;
  steps = map (test: builtins.head test.buildSteps) leaves;
  withExtra = suiteFor (base // { mkExtraTests = selected: { extra = selected.name; }; });
  rejects = value: !(builtins.tryEval (builtins.deepSeq value true)).success;
  results = {
    sameEightChecks = builtins.attrNames suite == names;
    ownedExecution = builtins.all (
      test:
      !(test ? stdenv)
      && test.tvp.kind == "owned-test"
      && test.compiler.outPath == compiler.outPath
      && test.specification.base.name == owned.name
    ) leaves;
    ownedInfrastructure = builtins.all (
      test:
      test.tvp.declaredInfrastructure.shell.outPath == bash.outPath
      && test.tvp.declaredInfrastructure.coreutils.outPath == coreutils.outPath
    ) leaves;
    selectedDrivers = builtins.all (
      step:
      step.env.CC == "${compiler}/bin/cc"
      && step.env.CXX == "${compiler}/bin/c++"
      && step.env.READELF == "${binutils}/bin/readelf"
    ) steps;
    noLegacyExecution = builtins.deepSeq (map (test: test.drvPath) leaves) true;
    extraInterfacePreserved = withExtra.extra == base.name;
    ownedSelectionRequired = rejects (suiteFor {
      name = "missing-owned-base";
    });
    directOwnedSelection =
      builtins.attrNames (suiteFor owned) == names
      && builtins.deepSeq (map (test: test.drvPath) (builtins.attrValues (suiteFor owned))) true;
  };
  failed = builtins.filter (name: !results.${name}) (builtins.attrNames results);
in
assert failed == [ ] || throw "Shared base tests: ${lib.concatStringsSep ", " failed}";
results

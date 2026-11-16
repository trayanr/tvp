# Actual source composition contracts. No compiler build or runtime claim.
{
  candidate ? import ../source-gcc13.nix { },
}:
let
  inherit (candidate) compiler driver constructionBase;
  full = candidate.family.full;
  selected = compiler.specification;
  same = a: b: a.drvPath == b.drvPath;
  results = {
    onlyProducedStage = builtins.attrNames candidate.family == [ "full" ];
    ownedContext = full ? tools && full ? compiler && !(full ? stdenv);
    sourceCompiler = compiler.rawCompiler && compiler.version == "13.3.0";
    reusableArtifact = compiler.artifact.drvPath != compiler.drvPath;
    earlierConstruction =
      selected.base ? compiler
      && !(selected.base ? stdenv)
      && same selected.base.compiler constructionBase.compiler
      && full.construction.previous == constructionBase.name;
    selectedDriver =
      same full.compiler driver && same full.tools.gcc driver && driver.version == compiler.version;
    selectedLibc =
      same selected.glibc constructionBase.compiler.libc && same driver.libc selected.glibc;
    closedTools = builtins.all (role: same full.tools.${role} constructionBase.tools.${role}) [
      "bash"
      "coreutils"
      "gnumake"
      "gnutar"
      "xz"
      "python"
      "patchelf"
    ];
    pureComposition = builtins.deepSeq {
      artifact = compiler.artifact.drvPath;
      final = compiler.drvPath;
      driver = driver.drvPath;
      provider = full.tools.gcc.drvPath;
    } true;
  };
  failed = builtins.filter (name: !results.${name}) (builtins.attrNames results);
in
assert
  failed == [ ] || throw "TVP source GCC13 contracts: ${builtins.concatStringsSep ", " failed}";
results

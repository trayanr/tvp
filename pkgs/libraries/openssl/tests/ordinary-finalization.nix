# Evaluation-only, IFD-free contract. Synthetic markers must never be executed.
{ package }:
let
  finalOnly = field: value:
    let changed = package.edit (spec: spec // { ${field} = value; });
    in {
      artifactSame = changed.artifact.drvPath == package.artifact.drvPath
        && changed.artifact.outPath == package.artifact.outPath;
      finalChanges = changed.drvPath != package.drvPath;
    };
in {
  manualHelper = finalOnly "manualHelper" (builtins.toFile "manual-helper-contract.py" "# identity marker\n");
  renderHelper = finalOnly "manualRenderer" (builtins.toFile "manual-render-contract.pl" "# identity marker\n");
  source = finalOnly "manualSource" (builtins.toFile "manual-source-contract.tar.gz" "identity marker\n");
  encoding = finalOnly "manualEncoding" "utf-8-contract-marker";
  perl = finalOnly "manualPerl" (builtins.toFile "manual-perl-contract" "identity marker\n");
  sections = finalOnly "manualSections" [
    { directory = "doc/contract"; section = "3"; exceptions = { }; }
  ];
}

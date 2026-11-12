# Evaluation-only, IFD-free contract. Synthetic markers must never be executed.
{ package }:
let
  rendererDeclared =
    selected:
    let
      relocate = builtins.head (
        builtins.filter (step: step.name == "openssl.relocate") selected.buildSteps
      );
      expected = builtins.getContext "${selected.specification.manualRenderer}";
      actual = builtins.getContext relocate.run;
    in
    expected != { }
    && builtins.all (path: builtins.hasAttr path actual && actual.${path} == expected.${path}) (
      builtins.attrNames expected
    );
  finalOnly =
    field: value:
    let
      changed = package.edit (spec: spec // { ${field} = value; });
    in
    {
      artifactSame =
        changed.artifact.drvPath == package.artifact.drvPath
        && changed.artifact.outPath == package.artifact.outPath;
      finalChanges = changed.drvPath != package.drvPath;
    };
in
{
  selfRuntimeDirectories = finalOnly "runtime" (
    package.specification.runtime
    // {
      selfLibraryDirectories = [
        "lib"
        "lib/final-only-contract"
      ];
    }
  );
  runtimeProviders = builtins.listToAttrs (
    map
      (
        field:
        let
          marker = builtins.toFile "${field}-contract" "runtime provider identity marker\n";
          changed = package.edit (spec: spec // { ${field} = marker; });
        in
        {
          name = field;
          value = (finalOnly field marker) // {
            effectiveProvider = builtins.elem marker (map toString changed.specification.runtime.tools);
          };
        }
      )
      [
        "runtimeCoreutils"
        "runtimeSed"
        "runtimeGrep"
        "runtimeGawk"
        "runtimeFindutils"
      ]
  );
  rendererInputs = {
    defaultPath = rendererDeclared package;
    editedPath = rendererDeclared (
      package.edit (
        spec:
        spec
        // {
          manualRenderer = ./ordinary-finalization.nix;
        }
      )
    );
    editedStoreString = rendererDeclared (
      package.edit (
        spec:
        spec
        // {
          manualRenderer = builtins.toFile "manual-render-input-contract.pl" "# identity marker\n";
        }
      )
    );
  };
  manualHelper = finalOnly "manualHelper" (
    builtins.toFile "manual-helper-contract.py" "# identity marker\n"
  );
  renderHelper = finalOnly "manualRenderer" (
    builtins.toFile "manual-render-contract.pl" "# identity marker\n"
  );
  source = finalOnly "manualSource" (
    builtins.toFile "manual-source-contract.tar.gz" "identity marker\n"
  );
  encoding = finalOnly "manualEncoding" "utf-8-contract-marker";
  perl = finalOnly "manualPerl" (builtins.toFile "manual-perl-contract" "identity marker\n");
  sections = finalOnly "manualSections" [
    {
      directory = "doc/contract";
      section = "3";
      exceptions = { };
    }
  ];
}

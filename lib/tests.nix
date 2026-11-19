{ lib }:
rec {
  selectLatest = import ./latest-tests.nix { inherit lib; };

  mkLatest =
    {
      context,
      selection,
      name ? "latest",
    }:
    (context.mkBatch {
      inherit name;
      suite = selection.batches;
    }).editSteps
      (
        plan:
        plan
        ++ [
          {
            name = "latest.outputs";
            run = ''
              for path in ${lib.escapeShellArgs selection.requiredOutputs}; do
                test -e "$path" || test -L "$path"
              done
            '';
          }
        ]
      );

  # Opt-in owned construction; catalogue factories must select this explicitly.
  forBase = import ./owned-tests.nix { inherit lib; };

  # Catalogue opt-in. Recompute after override/edit, including shell/Coreutils.
  fromPackage =
    { builder, package }:
    let
      spec = package.specification;
      base =
        if spec.base ? compiler then
          spec.base.override { shell = spec.bash; }
        else
          spec.base // { shell = spec.bash; };
    in
    (forBase {
      inherit builder base;
      coreutils = spec.coreutils;
      inlineScripts = spec.inlineScripts or false;
    })
    // {
      fixtures = fixtures.forBase {
        inherit builder;
        inherit (spec) base coreutils;
        bash = spec.bash;
        tools = spec.tools or spec.base.tools;
      };
    };

  # Ordinary package tests use forBase/fromPackage.
  # Remaining Nixpkgs-backed callers opt into the compatibility boundary.
  compatibility = import ./compatibility-tests.nix { inherit lib; };
  fixtures = import ./test-fixtures.nix;
}

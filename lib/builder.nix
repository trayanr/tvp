{ lib }:
let
  edits = import ./build-steps.nix;
  source = import ./owned-source-steps.nix { inherit lib; };
  builder = {
    __functor =
      _:
      import ./native-recipe.nix {
        inherit lib;
        owned = true;
      };
    steps = edits // source // { cmake = import ./cmake-steps.nix { inherit lib; }; };
    base = import ./owned-base.nix { inherit lib; };
    outputs = import ./native-output-steps.nix { inherit lib; };
    forBase = base: import ./base-context.nix { inherit lib builder base; };
  };
in
builder

{ lib }:
let
  edits = import ./build-steps.nix;
  source = import ./owned-source-steps.nix { inherit lib; };
in
{
  __functor =
    _:
    import ./native-recipe.nix {
      inherit lib;
      owned = true;
    };
  steps = edits // source // { cmake = import ./cmake-steps.nix { inherit lib; }; };
  outputs = import ./native-output-steps.nix { inherit lib; };
}

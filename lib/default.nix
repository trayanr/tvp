{ lib }:
let
  versions = import ./versions.nix { inherit lib; };
  tests = import ./tests.nix { inherit lib; };
  platforms = import ./platforms.nix { inherit lib; };
in
{
  inherit versions tests platforms;
  android = import ./android.nix { inherit lib; };
  provenance = import ./provenance.nix { inherit lib; };
  graph = import ./graph.nix { inherit lib; };
  bases = import ./bases.nix { inherit lib platforms; };
  packages = import ./packages.nix { inherit lib versions tests; };
}

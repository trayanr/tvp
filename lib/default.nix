{ lib }:
let
  versions = import ./versions.nix { inherit lib; };
in
{
  inherit versions;
  tests = import ./tests.nix { inherit lib; };
  bases = import ./bases.nix { inherit lib; };
  packages = import ./packages.nix { inherit lib versions; };
}

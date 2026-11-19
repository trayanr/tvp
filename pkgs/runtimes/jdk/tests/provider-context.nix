# Retained test-only capability; never an A/F construction input.
{ closureInfo }:
{
  package,
  lib,
  context,
}:
import ./installed.nix {
  inherit package lib;
  context = context // {
    closureInfo = package.testConfiguration.pkgs.closureInfo or closureInfo;
  };
}

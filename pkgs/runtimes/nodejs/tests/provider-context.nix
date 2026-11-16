# Retained test-only capability; never an A/F construction input.
{ pkgs }:
{
  package,
  lib,
  context,
}:
import ./installed.nix {
  inherit package lib;
  context = context // {
    callerPackages = package.testConfiguration.pkgs or pkgs;
  };
}

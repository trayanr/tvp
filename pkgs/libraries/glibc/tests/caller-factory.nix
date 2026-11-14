# Retained caller compatibility. Only the existing named pkgs override is
# forwarded, lazily; package production always remains on its owned constructor.
{ pkgs, tvp }:
pkgs.lib.makeOverridable (
  { pkgs }:
  package:
  if package ? testContext then
    (import ./installed.nix) {
      inherit package;
      lib = pkgs.lib;
      context = package.testContext;
    }
  else
    (import ../retained-construction.nix { inherit pkgs tvp; }).extraArgs.mkTests package
) { inherit pkgs; }

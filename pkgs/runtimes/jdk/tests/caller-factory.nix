# Retained caller compatibility. Only the existing named pkgs override is
# forwarded, lazily; package production always remains on its owned constructor.
{ pkgs, tvp }:
pkgs.lib.makeOverridable (
  { pkgs }:
  package:
  if package ? testContext then
    (import ./provider-context.nix { inherit pkgs; }) {
      inherit package;
      lib = pkgs.lib;
      context = package.testContext;
    }
  else
    (import ../legacy.nix { inherit pkgs tvp; }).packageArgs.extraArgs.mkTests package
) { inherit pkgs; }

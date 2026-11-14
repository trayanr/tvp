# Preserve the old legacy-package branch while retaining the ordinary tests
# override. Perl's public callback had no pkgs override to generalize here.
{
  lib,
  retained,
  tests,
}:
lib.makeOverridable (
  { tests }:
  package:
  if package ? testContext then
    tests {
      inherit package lib;
      context = package.testContext;
    }
  else
    retained.extraArgs.mkTests package
) { inherit tests; }

# Shared installed-test factory; keep caller pkgs overrides supported.
{ pkgs, tvpLib }:
pkgs.lib.makeOverridable (
  { pkgs }:
  mpfr:
  import ./default.nix {
    inherit tvpLib mpfr;
    pkgs =
      if mpfr ? testContext then
        pkgs
      else
        tvpLib.tests.withBase {
          inherit pkgs;
          base.stdenv = mpfr.stdenv;
        };
  }
) { inherit pkgs; }

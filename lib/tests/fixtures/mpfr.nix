# The real MPFR recipe in a construction scope, without a public compiler cycle.
{ pkgs, tvp }:
(import ../../../pkgs/libraries/mpfr { inherit pkgs tvp; }).instantiate {
  version = "4.2.2";
  base = tvp.baseTiers.seed;
  deps.gmp = (import ../../../bootstrap { }).gnu-gmp;
}

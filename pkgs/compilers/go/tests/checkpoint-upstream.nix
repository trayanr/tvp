# Original dist-test copy/run and exact full-suite acceptance policy, unchanged.
{
  package,
  lib,
  context,
}:
import package.specification.upstreamFactory {
  package = package // {
    testContext = context;
  };
  inherit lib;
  tvp.builder = import ../../../../lib/builder.nix { inherit lib; };
}

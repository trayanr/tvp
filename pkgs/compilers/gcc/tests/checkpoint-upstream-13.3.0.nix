# Uniform authoring entrypoint over the unchanged strict source-bound protocol.
{
  package,
  lib,
  context,
}:
import ./upstream-13.3.0.nix {
  package = package // {
    testContext = context;
  };
  inherit lib;
  tvp.builder = import ../../../../lib/builder.nix { inherit lib; };
}

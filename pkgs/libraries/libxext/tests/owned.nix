{
  package,
  lib,
  context,
}:
let
  tools = (package.specification.base.tools or { }) // {
    binutils = package.specification.base.compiler.bintools;
  };
in
import ../../../../lib/xorg-library-tests.nix {
  inherit package context;
  pc = "xext";
  apiPc = "xext";
  archive = "libXext";
  api = ./fixtures/api.c;
  consumer = ./fixtures/consumer.c;
}

// {
  upstream = import ./upstream.nix { inherit package lib context; };
}

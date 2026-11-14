{
  package,
  lib,
  context,
}:
let
  tools = (package.specification.base.standardTools or { }) // {
    binutils = package.specification.base.compiler.bintools;
  };
in
import ../../../../lib/xorg-library-tests.nix {
  inherit package context;
  pc = "xi";
  apiPc = "xi";
  archive = "libXi";
  api = ./fixtures/api.c;
  consumer = ./fixtures/consumer.c;
}

// {
  upstream = import ./upstream.nix { inherit package lib context; };
}

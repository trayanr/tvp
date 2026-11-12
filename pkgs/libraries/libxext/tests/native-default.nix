{
  pkgs,
  tvpLib,
  package,
}:
import ../../../../lib/xorg-library-tests.nix {
  inherit package;
  pc = "xext";
  apiPc = "xext";
  archive = "libXext";
  api = ./fixtures/api.c;
  consumer = ./fixtures/consumer.c;
}

// {
  upstream = import ./upstream.nix { inherit package; };
}

{
  pkgs,
  tvpLib,
  package,
}:
import ../../../../lib/xorg-library-tests.nix {
  inherit package;
  pc = "xtst";
  apiPc = "xtst x11";
  archive = "libXtst";
  api = ./fixtures/api.c;
  consumer = ./fixtures/consumer.c;
}

// {
  upstream = import ./upstream.nix { inherit package; };
}

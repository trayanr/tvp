{
  pkgs,
  tvpLib,
  package,
}:
import ../../../../lib/xorg-library-tests.nix {
  inherit package;
  pc = "xt";
  apiPc = "xt";
  archive = "libXt";
  api = ./fixtures/api.c;
  consumer = ./fixtures/consumer.c;
}

// {
  upstream = import ./upstream.nix { inherit package; };
}

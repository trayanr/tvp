{
  pkgs,
  tvpLib,
  package,
}:
import ../../../../lib/xorg-library-tests.nix {
  inherit package;
  pc = "xfixes";
  apiPc = "xfixes";
  archive = "libXfixes";
  api = ./fixtures/api.c;
  consumer = ./fixtures/consumer.c;
}

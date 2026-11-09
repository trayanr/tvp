{
  pkgs,
  tvpLib,
  package,
}:
import ../../../../lib/xorg-library-tests.nix {
  inherit package;
  pc = "xrandr";
  apiPc = "xrandr";
  archive = "libXrandr";
  api = ./fixtures/api.c;
  consumer = ./fixtures/consumer.c;
}

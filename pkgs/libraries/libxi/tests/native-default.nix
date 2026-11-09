{
  pkgs,
  tvpLib,
  package,
}:
import ../../../../lib/xorg-library-tests.nix {
  inherit package;
  pc = "xi";
  apiPc = "xi";
  archive = "libXi";
  api = ./fixtures/api.c;
  consumer = ./fixtures/consumer.c;
}

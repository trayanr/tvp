{ pkgs, tvp }:
{
  "8.5.9" = {
    builder = ./build-8.5.nix;
    sha256 = "sha256-1zVFnCy66wZz1BbDPTctn/Jh1WL2sp2kjz5q6uygg68=";
    deps = {
      openssl = tvp.packages.openssl_3_5_7;
      zlib = tvp.packages.zlib_1_3_2;
      libxml2 = tvp.packages.libxml2_2_15_3;
      readline = tvp.packages.readline_8_3;
      ncurses = tvp.packages.ncurses_6_6;
      sqlite = pkgs.sqlite;
      pkg-config = tvp.packages."pkg-config_0_29_2";
    };
  };

}

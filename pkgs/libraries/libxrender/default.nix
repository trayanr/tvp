{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "0.9.13" = {
      builder = ./build-0.9.13.nix;
      base = tvp.bases.default;
      deps = {
        pkg-config = tvp.packages.pkg-config_0_29_2;
        patchelf = tvp.packages.patchelf_0_19_2;
        libx11 = tvp.packages.libx11_1_8_14;
        xorgproto = tvp.packages.xorgproto_2026_1;
        xtrans = tvp.packages.xtrans_1_6_0;
        libxcb = tvp.packages.libxcb_1_17_0;
        libxau = tvp.packages.libxau_1_0_12;
        libxdmcp = tvp.packages.libxdmcp_1_1_5;
      };
    };
  };
  pname = "libxrender";
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."0.9.13";
      releases."0.9.13" = "sha256-P+iMYJ32eC4eevLk3jayVj1wzXD/fcsc2lYa1kkSu2Q=";
    }
  ];
  canonical = tvpLib.packages.mkVersions {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests =
      package:
      import ./tests {
        inherit tvpLib package;
        pkgs = tvpLib.tests.withBase {
          inherit pkgs;
          base.stdenv = package.stdenv;
        };
      };
  };
in
{
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

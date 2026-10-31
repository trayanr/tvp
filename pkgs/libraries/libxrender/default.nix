{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "0.9.13" = {
      builder = ./build-0.9.13.nix;
      base = tvp.bases.default;
      deps = {
        pkg-config = tvp.packages.pkg-config;
        patchelf = tvp.packages.patchelf;
        libx11 = tvp.packages.libx11_1;
        xorgproto = tvp.packages.xorgproto;
        xtrans = tvp.packages.xtrans_1;
        libxcb = tvp.packages.libxcb_1;
        libxau = tvp.packages.libxau_1;
        libxdmcp = tvp.packages.libxdmcp_1;
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

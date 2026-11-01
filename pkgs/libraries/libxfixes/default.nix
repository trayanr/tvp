{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "6.0.2" = {
      builder = ./build-6.0.2.nix;
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
  pname = "libxfixes";
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."6.0.2";
      releases."6.0.2" = "sha256-OfEV1y2cX4ER5GhBZNPWjMH9Ifmyf/JAGwj938D0Cbo=";
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

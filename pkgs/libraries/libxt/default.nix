{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "1.3.1" = {
      builder = ./build-1.3.1.nix;
      base = tvp.bases.default;
      deps = {
        pkg-config = tvp.packages.pkg-config;
        patchelf = tvp.packages.patchelf;
        libsm = tvp.packages.libsm_1;
        libice = tvp.packages.libice_1;
        libx11 = tvp.packages.libx11_1;
        xorgproto = tvp.packages.xorgproto;
        xtrans = tvp.packages.xtrans_1;
        libxcb = tvp.packages.libxcb_1;
        libxau = tvp.packages.libxau_1;
        libxdmcp = tvp.packages.libxdmcp_1;
      };
    };
  };
  pname = "libxt";
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."1.3.1";
      releases."1.3.1" = "sha256-4Kd0szMk9NTAWxmepFBQ+HIGWG2BZV+L7026Q02TEog=";
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

{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "1.1.2" = {
      builder = ./build-1.1.2.nix;
      base = tvp.bases.default;
      deps = {
        pkg-config = tvp.packages.pkg-config_0_29_2;
        patchelf = tvp.packages.patchelf_0_19_2;
        xorgproto = tvp.packages.xorgproto_2026_1;
        xtrans = tvp.packages.xtrans_1_6_0;
      };
    };
  };
  pname = "libice";
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."1.1.2";
      releases."1.1.2" = "sha256-l05O1BQiXrPHFphd+XCfTajSKmeiiQBmvG38ia0phiU=";
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

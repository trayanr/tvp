{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "1.1.2" = {
      builder = ./build-1.1.2.nix;
      base = tvp.bases.default;
      deps = {
        pkg-config = tvp.packages.pkg-config;
        patchelf = tvp.packages.patchelf;
        xorgproto = tvp.packages.xorgproto;
        xtrans = tvp.packages.xtrans_1;
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

{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "1.2.6" = {
      builder = ./build-1.2.6.nix;
      base = tvp.bases.default;
      deps = {
        pkg-config = tvp.packages.pkg-config;
        patchelf = tvp.packages.patchelf;
        libice = tvp.packages.libice_1;
        xorgproto = tvp.packages.xorgproto;
        xtrans = tvp.packages.xtrans_1;
      };
    };
  };
  pname = "libsm";
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."1.2.6";
      releases."1.2.6" = "sha256-vnwKvbFcv9KaxiVzwcguh3+dQEetFTIefql9HkPYNb4=";
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

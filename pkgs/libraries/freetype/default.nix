{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "2.15.0" = {
      builder = ./build-2.15.0.nix;
      base = tvp.bases.default;
      deps = {
        pkg-config = tvp.packages.pkg-config;
        zlib = tvp.packages.zlib_1;
        bzip2 = tvp.packages.bzip2_1;
        patchelf = tvp.packages.patchelf;
      };
    };
  };
  pname = "freetype";
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."2.15.0";
      releases."2.15.0" = "sha256-k81H63GcMlEH8tPPCH0GKZ6UTDtIpAtVU3MCME3qHdU=";
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

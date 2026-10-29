{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "2.15.0" = {
      builder = ./build-2.15.0.nix;
      base = tvp.bases.default;
      deps = {
        pkg-config = tvp.packages.pkg-config_0_29_2;
        zlib = tvp.packages.zlib_1_3_2;
        bzip2 = tvp.packages.bzip2_1_0_8;
        patchelf = tvp.packages.patchelf_0_19_2;
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

{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "2.9.0" = {
      builder = ./build-2.9.0.nix;
      base = tvp.bases.default;
      deps = {
        cmake = tvp.packages.cmake_4_4_5;
        ninja = tvp.packages.ninja_1_13_2;
        patchelf = tvp.packages.patchelf_0_19_2;
      };
    };
  };
  pname = "expat";
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."2.9.0";
      releases."2.9.0" = "sha256-HmNxhizDGZmzaMO4m0mZTwZ34bq18bK4WuN0H12AMFE=";
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

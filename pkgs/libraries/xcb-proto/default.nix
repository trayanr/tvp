{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "1.17.0" = {
      builder = ./build-1.17.0.nix;
      base = tvp.bases.default;
      deps = {
        pkg-config = tvp.packages.pkg-config_0_29_2;
        python = tvp.packages.python-build_3_12_5;
      };
    };
  };
  pname = "xcb-proto";
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."1.17.0";
      releases."1.17.0" = "sha256-LBus0hEPR5n3TebrtxS5TPb4D7ESMWsSGUgP0iViFIw=";
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

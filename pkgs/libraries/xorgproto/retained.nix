{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "2026.1" = {
      builder = ./build-2026.1.nix;
      base = tvp.bases.default;
      deps = {
        pkg-config = tvp.packages.pkg-config;
      };
    };
  };
  pname = "xorgproto";
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."2026.1";
      releases."2026.1" = "sha256-+b/kqe2MirnSo7DUl5fwRgUtrdBreotF2/+v+xN+gpA=";
    }
  ];
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      import ./tests {
        inherit tvpLib package;
        pkgs = tvpLib.tests.withBase {
          inherit pkgs;
          base.stdenv = package.stdenv;
        };
      }
    ) { inherit pkgs; };
  };
  canonical = tvpLib.packages.mkVersions packageArgs;
in
{
  inherit canonical packageArgs;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

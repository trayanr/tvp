{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "0.19.2" = {
      builder = ./build-0.19.2.nix;
      base = tvp.bases.default;
      deps = { };
    };
  };
  pname = "patchelf";
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."0.19.2";
      releases."0.19.2" = "sha256-1K2aTlxongkRnOLzCpSw6LT5jHhZASPqIWZeNMaSiAE=";
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

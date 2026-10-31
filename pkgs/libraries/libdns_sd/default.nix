{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "2881.120.11" = {
      builder = ./build-2881.120.11.nix;
      base = tvp.bases.default;
      deps.patchelf = tvp.packages.patchelf;
    };
  };
  pname = "libdns_sd";
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."2881.120.11";
      releases."2881.120.11" = "sha256-9mXPArXJMPm3D7ObdWfwPdghmXWUxWzjmQmOqgNy+xU=";
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

{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "1.13" = {
      builder = ./build-1.13.nix;
      base = tvp.bases.default;
      deps = {
        gnugrep = tvp.packages.gnugrep_3_11;
      };
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."1.13";
      releases."1.13" = "sha256-dFTraTXbF8ZlVXbC4bD6vv04tNCTbg+H9IzQYs6RoFc=";
    }
  ];
  pname = "gzip";
  canonical = tvpLib.packages.mkVersions {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests = package: import ./tests { inherit pkgs tvpLib package; };
  };
in
{
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

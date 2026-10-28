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
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests = package: import ./tests { inherit pkgs tvpLib package; };
  };
  canonical = tvpLib.packages.mkVersions packageArgs;
  variants = tvpLib.packages.mkVariants (
    packageArgs
    // {
      inherit pkgs;
      profiles.gcc13 = {
        base = tvp.bases.gcc13;
        versions."1.13" = {
          deps = {
            gnugrep = tvp.variants.gcc13.gnugrep_3_11;
          };
        };
      };
    }
  );

in
{
  inherit canonical variants;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

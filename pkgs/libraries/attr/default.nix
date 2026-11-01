{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "2.5.0" = {
      builder = ./build-2.5.0.nix;
      base = tvp.bases.default;
      deps = { };
    };
    "2.5.2" = {
      builder = ./build-2.5.2.nix;
      base = tvp.bases.default;
      deps = {

      };
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."2.5.0";
      releases = {
        "2.5.0" = "sha256-QhUBw/elarEuLDShh7yuRPfRQfllreGNAeYmHROPFjs=";
        "2.5.1" = "sha256-uuHGlJslig1oABNnzgx0HOvazdO2KWXRfl6yPNeK2vg=";
      };
    }
    {
      def = defs."2.5.2";
      releases = {
        "2.5.2" = "sha256-Ob9nRS+kHQlIwhl2AQU/SLPXigKTiXNDMqYwmmgMbIc=";
        "2.6.0" = "sha256-1C+jdFExgLtIyxGkZpb0iCQOUST/HmrYiwq/9waYVhI=";
      };
    }
  ];
  pname = "attr";
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests = package: import ./tests { inherit pkgs tvpLib package; };
    packageMeta.upstream = {
      type = "directory-index";
      url = "https://download.savannah.nongnu.org/releases/attr/";
      # Extract the complete filename first: a family-specific substring would
      # turn prefixattr-2.6.0.tar.gz into a false attr release.
      pattern = ''[^"<>/[:space:]]+\.tar\.[^"<>/[:space:]]+'';
      normalise =
        file:
        let
          match = builtins.match "attr-([0-9]+\\.[0-9]+\\.[0-9]+)(\\.src)?\\.tar\\.gz" file;
        in
        if match == null then null else builtins.head match;
    };
  };
  canonical = tvpLib.packages.mkVersions packageArgs;

in
{
  recipes.${pname} = packageArgs;
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

{ tvp, ... }:
let
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        opts.installedInterface.libraryFile = "libattr.so.1.1.250";
        opts.upstreamProfile = "test";
      };
      releases."2.5.0" = "sha256-QhUBw/elarEuLDShh7yuRPfRQfllreGNAeYmHROPFjs=";
    }
    {
      def = {
        builder = ./build.nix;
        opts.installedInterface.libraryFile = "libattr.so.1.1.2501";
        opts.upstreamProfile = "test";
      };
      releases."2.5.1" = "sha256-uuHGlJslig1oABNnzgx0HOvazdO2KWXRfl6yPNeK2vg=";
    }
    {
      def = {
        builder = ./build.nix;
        opts.installedInterface.libraryFile = "libattr.so.1.1.2502";
        opts.upstreamProfile = "test";
      };
      releases."2.5.2" = "sha256-Ob9nRS+kHQlIwhl2AQU/SLPXigKTiXNDMqYwmmgMbIc=";
    }
    {
      def = {
        builder = ./build.nix;
        opts.installedInterface.libraryFile = "libattr.so.1.1.2600";
      };
      releases."2.6.0" = "sha256-1C+jdFExgLtIyxGkZpb0iCQOUST/HmrYiwq/9waYVhI=";
    }
  ];
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
  pname = "attr";
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable packageMeta;
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://download.savannah.nongnu.org/releases/attr/attr-${version}.tar.gz";
        inherit sha256;
      };
    tests = import ./tests/installed.nix;
    testDeps = {
      pkg-config = tvp.packages.pkg-config;
      perl = tvp.packages.perl_5;
    };
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.attr = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

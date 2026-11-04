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
  completed = tvp.bases.default;
  seed =
    reason:
    tvpLib.packages.withConstraint {
      category = "construction";
      inherit reason;
    };
  floorTool =
    name:
    seed
      "Completed default-base ${name} is a build-only seed; the canonical Coreutils/Tar graph consumes Attr/ACL and would recurse through these libraries."
      completed.components.floor.${name};
  ownedDefs = tvpLib.packages.mkDefs {
    "2.6.0" = {
      constructor = tvp.builder;
      builder = ./owned/build-2.6.0.nix;
      base = completed;
      helpers = {
        inherit tvp;
      };
      deps = {
        bash = floorTool "bash";
        coreutils = floorTool "coreutils";
        gnumake = tvp.packages.gnumake_4;
        gnutar = floorTool "gnutar";
        gzip = floorTool "gzip";
        python = seed "Completed libc-build Python runs source/output operations without a canonical Python dependency cycle." completed.components.libc.tvp.deps.python3Minimal;
        perl = seed "Completed base Perl executes the build-only upstream test harness without a canonical Perl/libxcrypt prerequisite cycle." completed.components.perl;
        binutils = seed "Completed base Binutils supplies build-only stripping and inspection before its compression prerequisites advance." completed.components.binutils;
        patchelf = seed "Completed base Patchelf finalizes ELF without recursing through its XZ archive prerequisites." completed.fixupTools.patchelf;
      };
    };
  };
  publicVersionTable = versionTable // {
    "2.6.0" = versionTable."2.6.0" // {
      def = ownedDefs."2.6.0";
    };
  };
  publicArgs = packageArgs // {
    testDeps.pkg-config = tvp.packages.pkg-config;
    versionTable = publicVersionTable;
    source =
      { version, sha256 }:
      pkgs.fetchurl {
        url = "https://download.savannah.nongnu.org/releases/attr/attr-${version}.tar.gz";
        inherit sha256;
      };
    extraArgs.mkTests =
      package:
      packageArgs.extraArgs.mkTests package
      // pkgs.lib.optionalAttrs (package.version == "2.6.0") (
        import ./tests/owned.nix {
          inherit tvpLib package;
          pkgs = tvpLib.tests.withBase {
            inherit pkgs;
            base.stdenv = package.stdenv;
          };
        }
      );
  };
  constructionRecipe = packageArgs;
  canonical = tvpLib.packages.mkVersions publicArgs;

in
{
  recipes.${pname} = publicArgs // {
    inherit constructionRecipe;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

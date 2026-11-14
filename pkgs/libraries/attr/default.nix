{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  candidate = import ../../../bases/source-gnu { };
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
  legacyDefs = tvpLib.packages.mkDefs {
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
  ownedDefs = tvpLib.packages.mkDefs {
    "2.6.0" = {
      constructor = tvp.builder;
      builder = ./native/build-2.6.0.nix;
      base = candidate.base;
      source =
        { version, sha256 }:
        import <nix/fetchurl.nix> {
          url = "https://download.savannah.nongnu.org/releases/attr/attr-${version}.tar.gz";
          inherit sha256;
        };
      testContext =
        package:
        tvpLib.tests.fromPackage {
          builder = tvp.builder;
          inherit package;
        };
      helpers = {
        inherit tvp;
      };
      # Retained source-built host tools avoid Coreutils/Tar/Perl/archive cycles.
      deps = {
        inherit (candidate.tools)
          bash
          coreutils
          gzip
          python
          binutils
          patchelf
          sed
          grep
          gawk
          diffutils
          findutils
          perl
          ;
        gnumake = candidate.tools.make;
        gnutar = candidate.tools.tar;
      };
    };
  };
  publicVersionTable = versionTable // {
    "2.6.0" = versionTable."2.6.0" // {
      def = if native then ownedDefs."2.6.0" else legacyDefs."2.6.0";
    };
  };
  constructionTool =
    name:
    tvpLib.packages.withConstraint {
      category = "construction";
      reason = "Retained source-GNU ${name} is a build-only host generation; ordinary Coreutils/Tar/Perl consume these target libraries.";
    } candidate.tools.${name};
  ordinaryDefs = import ./ordinary {
    inherit
      tvp
      tvpLib
      candidate
      constructionTool
      ;
  };
  publicArgs = packageArgs // {
    testDeps.pkg-config = tvp.packages.pkg-config;
    versionTable = publicVersionTable // {
      "2.5.0" = versionTable."2.5.0" // {
        def = if native then ordinaryDefs."2.5.0" else versionTable."2.5.0".def;
      };
      "2.5.1" = versionTable."2.5.1" // {
        def = if native then ordinaryDefs."2.5.1" else versionTable."2.5.1".def;
      };
      "2.5.2" = versionTable."2.5.2" // {
        def = if native then ordinaryDefs."2.5.2" else versionTable."2.5.2".def;
      };
    };
    source =
      { version, sha256 }:
      pkgs.fetchurl {
        url = "https://download.savannah.nongnu.org/releases/attr/attr-${version}.tar.gz";
        inherit sha256;
      };
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      (
        (
          package:
          (import ./tests { inherit pkgs tvpLib package; })
          // pkgs.lib.optionalAttrs (package.version == "2.6.0") (
            import ./tests/owned.nix {
              inherit tvpLib package;
              pkgs =
                if package ? testContext then
                  pkgs
                else
                  tvpLib.tests.withBase {
                    inherit pkgs;
                    base.stdenv = package.stdenv;
                  };
            }
          )
        )
        package
      )
      //
        pkgs.lib.optionalAttrs
          (
            package ? testContext
            && builtins.elem package.version [
              "2.5.0"
              "2.5.1"
              "2.5.2"
            ]
          )
          (
            import ./tests/ordinary.nix {
              inherit
                pkgs
                tvpLib
                package
                tvp
                ;
            }
          )
    ) { inherit pkgs; };
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

{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  candidate = import ../../../bases/source-gnu { };
  defs = tvpLib.packages.mkDefs {
    "2.3.0" = {
      builder = ./build-2.3.0.nix;
      # Measured 2.3.0/1 abort under GCC16 FORTIFY: libobj.h nests a
      # zero-length string subobject; 2.3.2 flattens it. Preserve the sources
      # and hardening on the verified compatibility compiler.
      base = tvp.bases.gcc13-owned-v3;
      deps.attr = tvp.packages.attr_2;
    };
    "2.3.2" = {
      builder = ./build-2.3.2.nix;
      base = tvp.bases.default;
      deps = {
        attr = tvp.packages.attr_2;
      };
    };
    "2.4.0" = {
      builder = ./build-2.4.0.nix;
      base = tvp.bases.default;
      deps.attr = tvp.packages.attr_2;
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."2.3.0";
      releases = {
        "2.3.0" = "sha256-vTj9u7A8eTdK9RRn6+VJfLwDNbgld/MMlRpBqVtTMAk=";
        "2.3.1" = "sha256-dgxhxokBs3/dXu/ur0wMeia9/disdHoe3/HODiQ8Ea8=";
      };
    }
    {
      def = defs."2.3.2";
      releases."2.3.2" = "sha256-XyvbrWKXB6p9hcYj+ZSqih0t7FWnPeUgW6wL9gWKL3w=";
    }
    {
      def = defs."2.4.0";
      releases."2.4.0" = "sha256-c8hTw9ROH2k+WpaphvG9GdPQ2sLH1FPnlhd3dLxOX2o=";
    }
  ];
  pname = "acl";
  packageArgs = {
    testDeps.pkg-config = tvp.packages.pkg-config;
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests =
      package:
      import ./tests {
        inherit pkgs tvpLib package;
        pkg-config = package.tvp.declaredTestDependencies.pkg-config;
      };
    packageMeta.upstream = {
      type = "directory-index";
      url = "https://download.savannah.nongnu.org/releases/acl/";
      # Extract complete archive filenames before applying the strict family parser.
      pattern = "[^\"<>[:space:]]+\\.tar\\.(gz|xz)[^\"<>[:space:]]*";
      normalise =
        filename:
        let
          m = builtins.match "acl-([0-9]+\\.[0-9]+\\.[0-9]+)(\\.src)?\\.tar\\.(gz|xz)" filename;
        in
        if m == null then null else builtins.head m;
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
    "2.4.0" = {
      constructor = tvp.builder;
      builder = ./owned/build-2.4.0.nix;
      base = completed;
      helpers = {
        inherit tvp;
      };
      deps = {
        attr = tvp.packages.attr_2;
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
    "2.3.2" = {
      constructor = tvp.builder;
      builder = ./native/build-2.3.2.nix;
      base = candidate.base;
      source =
        { version, sha256 }:
        import <nix/fetchurl.nix> {
          url = "https://download.savannah.nongnu.org/releases/acl/acl-${version}.tar.gz";
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
        attr = tvp.packages.attr_2;
      };
    };
    "2.4.0" = {
      constructor = tvp.builder;
      builder = ./native/build-2.4.0.nix;
      base = candidate.base;
      source =
        { version, sha256 }:
        import <nix/fetchurl.nix> {
          url = "https://download.savannah.nongnu.org/releases/acl/acl-${version}.tar.gz";
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
        attr = tvp.packages.attr_2;
      };
    };
  };
  publicVersionTable = versionTable // {
    "2.3.2" = versionTable."2.3.2" // {
      def = if native then ownedDefs."2.3.2" else defs."2.3.2";
    };
    "2.4.0" = versionTable."2.4.0" // {
      def = if native then ownedDefs."2.4.0" else legacyDefs."2.4.0";
    };
  };
  publicArgs = packageArgs // {
    versionTable = publicVersionTable;
    source =
      { version, sha256 }:
      pkgs.fetchurl {
        url = "https://download.savannah.nongnu.org/releases/acl/acl-${version}.tar.gz";
        inherit sha256;
      };
    extraArgs.mkTests =
      package:
      packageArgs.extraArgs.mkTests package
      // pkgs.lib.optionalAttrs (package ? testContext && package.version == "2.3.2") (
        import ../../../lib/tests/command-source-edit.nix {
          inherit tvp package;
          compression = "gzip";
        }
      )
      // pkgs.lib.optionalAttrs (package.version == "2.4.0" || package ? testContext) (
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

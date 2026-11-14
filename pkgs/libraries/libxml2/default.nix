{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  testLib = pkgs.lib;
  previous = import ./legacy.nix { inherit pkgs tvp; };
  formerRecipe = previous.publicArgs;
  candidate = import ../../../bases/source-gnu { };
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  constructionTool =
    name:
    tvpLib.packages.withConstraint {
      category = "construction";
      reason = "Retained source-GNU ${name} is an independent build-only host generation; ordinary Python/Binutils are downstream of this library wave.";
    } candidate.tools.${name};
  defs = tvpLib.packages.mkDefs {
    "2.7.4" = {
      constructor = tvp.builder;
      base = candidate.base;
      helpers = {
        inherit tvp;
      };
      testContext =
        package:
        tvpLib.tests.fromPackage {
          builder = tvp.builder;
          inherit package;
        };
      builder = ./ordinary/build-2.7.nix;
      opts = {
        cStandard = "gnu89";
        libraryAbi = "2";
      };
      deps = {
        inherit (tvp.packages)
          bash
          coreutils
          gnumake
          gnutar
          gnused
          gnugrep
          gawk
          diffutils
          findutils
          ;
        zlib = tvp.packages.zlib_1;
        xz = tvp.packages.xz_5;
        pkg-config = tvp.packages.pkg-config;
        python = tvp.packages.python_3;
        binutils = tvp.packages.binutils_2;
        patchelf = tvp.packages.patchelf_0;
      };
    };
    "2.8.0" = {
      constructor = tvp.builder;
      base = candidate.base;
      helpers = {
        inherit tvp;
      };
      testContext =
        package:
        tvpLib.tests.fromPackage {
          builder = tvp.builder;
          inherit package;
        };
      builder = ./ordinary/build-2.8.nix;
      opts = {
        cStandard = "gnu89";
        libraryAbi = "2";
      };
      deps = {
        inherit (tvp.packages)
          bash
          coreutils
          gnumake
          gnutar
          gnused
          gnugrep
          gawk
          diffutils
          findutils
          ;
        zlib = tvp.packages.zlib_1;
        xz = tvp.packages.xz_5;
        liblzma = tvp.packages.xz_5;
        pkg-config = tvp.packages.pkg-config;
        python = tvp.packages.python_3;
        binutils = tvp.packages.binutils_2;
        patchelf = tvp.packages.patchelf_0;
      };
    };
    "2.9.5" = {
      constructor = tvp.builder;
      base = candidate.base;
      helpers = {
        inherit tvp;
      };
      testContext =
        package:
        tvpLib.tests.fromPackage {
          builder = tvp.builder;
          inherit package;
        };
      builder = ./ordinary/build-2.8.nix;
      opts = {
        cStandard = "gnu17";
        libraryAbi = "2";
      };
      deps = {
        inherit (tvp.packages)
          bash
          coreutils
          gnumake
          gnutar
          gnused
          gnugrep
          gawk
          diffutils
          findutils
          ;
        zlib = tvp.packages.zlib_1;
        xz = tvp.packages.xz_5;
        liblzma = tvp.packages.xz_5;
        pkg-config = tvp.packages.pkg-config;
        python = tvp.packages.python_3;
        binutils = tvp.packages.binutils_2;
        patchelf = tvp.packages.patchelf_0;
      };
    };
    "2.10.0" = {
      constructor = tvp.builder;
      base = candidate.base;
      helpers = {
        inherit tvp;
      };
      testContext =
        package:
        tvpLib.tests.fromPackage {
          builder = tvp.builder;
          inherit package;
        };
      builder = ./ordinary/build-2.10.nix;
      opts = {
        cStandard = "gnu17";
        libraryAbi = "2";
      };
      deps = {
        inherit (tvp.packages)
          bash
          coreutils
          gnumake
          gnutar
          gnused
          gnugrep
          gawk
          diffutils
          findutils
          ;
        zlib = tvp.packages.zlib_1;
        xz = tvp.packages.xz_5;
        liblzma = tvp.packages.xz_5;
        pkg-config = tvp.packages.pkg-config;
        python = tvp.packages.python_3;
        binutils = tvp.packages.binutils_2;
        patchelf = tvp.packages.patchelf_0;
      };
    };
    "2.13.0" = {
      constructor = tvp.builder;
      base = candidate.base;
      helpers = {
        inherit tvp;
      };
      testContext =
        package:
        tvpLib.tests.fromPackage {
          builder = tvp.builder;
          inherit package;
        };
      builder = ./ordinary/build-2.13.nix;
      opts = {
        cStandard = "gnu17";
        libraryAbi = "2";
      };
      deps = {
        inherit (tvp.packages)
          bash
          coreutils
          gnumake
          gnutar
          gnused
          gnugrep
          gawk
          diffutils
          findutils
          ;
        zlib = tvp.packages.zlib_1;
        xz = tvp.packages.xz_5;
        liblzma = tvp.packages.xz_5;
        pkg-config = tvp.packages.pkg-config;
        python = tvp.packages.python_3;
        binutils = tvp.packages.binutils_2;
        patchelf = tvp.packages.patchelf_0;
      };
    };
    "2.14.0" = {
      constructor = tvp.builder;
      base = candidate.base;
      helpers = {
        inherit tvp;
      };
      testContext =
        package:
        tvpLib.tests.fromPackage {
          builder = tvp.builder;
          inherit package;
        };
      builder = ./ordinary/build-2.13.nix;
      opts = {
        cStandard = "gnu17";
        libraryAbi = "16";
      };
      deps = {
        inherit (tvp.packages)
          bash
          coreutils
          gnumake
          gnutar
          gnused
          gnugrep
          gawk
          diffutils
          findutils
          ;
        zlib = tvp.packages.zlib_1;
        xz = tvp.packages.xz_5;
        liblzma = tvp.packages.xz_5;
        pkg-config = tvp.packages.pkg-config;
        python = tvp.packages.python_3;
        binutils = tvp.packages.binutils_2;
        patchelf = tvp.packages.patchelf_0;
      };
    };
    "2.15.0" = {
      constructor = tvp.builder;
      base = candidate.base;
      helpers = {
        inherit tvp;
      };
      testContext =
        package:
        tvpLib.tests.fromPackage {
          builder = tvp.builder;
          inherit package;
        };
      builder = ./ordinary/build-2.15.nix;
      opts = {
        cStandard = "gnu17";
        libraryAbi = "16";
      };
      deps = {
        inherit (tvp.packages)
          bash
          coreutils
          gnumake
          gnutar
          gnused
          gnugrep
          gawk
          diffutils
          findutils
          ;
        zlib = tvp.packages.zlib_1;
        xz = tvp.packages.xz_5;
        pkg-config = tvp.packages.pkg-config;
        python = tvp.packages.python_3;
        binutils = tvp.packages.binutils_2;
        patchelf = tvp.packages.patchelf_0;
      };
    };
    "2.15.4" = {
      constructor = tvp.builder;
      builder = ./native/build-2.15.4.nix;
      base = candidate.base;
      helpers = {
        inherit tvp;
      };
      testContext =
        package:
        tvpLib.tests.fromPackage {
          builder = tvp.builder;
          inherit package;
        };
      deps = {
        inherit (tvp.packages)
          bash
          coreutils
          gnumake
          gnutar
          gnused
          gnugrep
          gawk
          diffutils
          findutils
          ;
        xz = tvp.packages.xz_5;
        zlib = tvp.packages.zlib_1;
        pkg-config = tvp.packages.pkg-config;
        python = constructionTool "python";
        binutils = constructionTool "binutils";
        patchelf = constructionTool "patchelf";
      };
    };
  };
  # Explicit release blocks preserve hashes/status and retain construction and
  # nonnative routing. No latest dispatch or argument/result adaptation.
  ownedVersionTable = tvpLib.packages.mkTable (import ./ordinary/2.nix { inherit defs; });
  versionTable = builtins.mapAttrs (
    version: entry: if native then entry // { def = ownedVersionTable.${version}.def; } else entry
  ) formerRecipe.versionTable;
  publicArgs = formerRecipe // {
    inherit versionTable;
    source =
      { version, sha256 }:
      pkgs.fetchurl {
        url = "https://download.gnome.org/sources/libxml2/${testLib.versions.majorMinor version}/libxml2-${version}.tar.xz";
        inherit sha256;
      };
    extraArgs.mkTests = testLib.makeOverridable (
      { pkgs }:
      libxml2:
      import ./tests {
        inherit tvpLib libxml2;
        pkgs = if libxml2 ? testContext then { lib = testLib; } else pkgs;
        inherit (libxml2.tvp.declaredTestDependencies) pkg-config gzip xz;
      }
    ) { inherit pkgs; };
  };
  canonical = tvpLib.packages.mkVersions publicArgs;
  pname = "libxml2";
in
{
  recipes.${pname} = publicArgs // {
    constructionRecipe = formerRecipe;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

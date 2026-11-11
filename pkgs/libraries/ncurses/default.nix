{ pkgs, tvp }:
let
  tvpLib = tvp.lib;

  defs = tvpLib.packages.mkDefs {
    "6.2" = {
      builder = ./build-6.0.nix;
      # A C23 bool probe causes these releases to redefine C++ bool in
      # curses.h. 6.6 fixes that header guard; retain C++ bindings and tests.
      opts.cStandard = "gnu17";
      base = tvp.bases.default;
      deps = {
        pkg-config = tvp.packages.pkg-config;
      };
    };

    "6.6" = {
      builder = ./build-6.0.nix;
      base = tvp.bases.default;
      deps.pkg-config = tvp.packages.pkg-config;
    };

    # Retain the historical C/C++ dialects: C23 bool detection breaks these
    # headers, and 6.0 etip.h uses the pre-C++17 operator-new declaration.
    "6.0" = {
      builder = ./build-6.0.nix;
      base = tvp.bases.default;
      opts = {
        cStandard = "gnu17";
        cxxStandard = "gnu++14";
      };
      deps = {
        pkg-config = tvp.packages.pkg-config;
      };
    };

    # MKlib_gen.sh needs -P with modern preprocessors; 6.0 adds that detection.
    "5.8" = {
      builder = ./build-5.8.nix;
      patches = [
        {
          file = ./patches/const-user-getters-5.5.patch;
          reason = "Const UserData callers require observational getters to be const; GCC16 checks template bodies eagerly.";
        }
      ];
      base = tvp.bases.default;
      deps = {
        pkg-config = tvp.packages.pkg-config;
      };
      opts = {
        hardeningDisable = [ "format" ];
        cStandard = "gnu89";
        cxxStandard = "gnu++98";
      };
    };

    # 5.0 … 5.2 hard-code <strstream.h> in cursesw.h, from the pre-standard C++
    # library. 5.3 made the include conditional on HAVE_STRSTREAM_H.
    "5.0" = {
      builder = ./build-4.2.nix;
      base = tvp.bases.default;
      deps = {
        gnu-config = tvp.packages.gnu-config;
      };
      opts = {
        hardeningDisable = [ "format" ];
        cStandard = "gnu89";
        cxxStandard = "gnu++98";
        cxxBinding = false;
      };
    };

    "5.3" = {
      builder = ./build-4.2.nix;
      base = tvp.bases.default;
      deps = {
        gnu-config = tvp.packages.gnu-config;
      };
      patches = [
        {
          file = ./patches/const-user-getters-5.3.patch;
          reason = "Preserve const UserData API by const-qualifying observational getters; GCC16 checks the template body eagerly.";
        }
      ];
      opts = {
        hardeningDisable = [ "format" ];
        cStandard = "gnu89";
        cxxStandard = "gnu++98";
      };
    };

    "5.5" = {
      builder = ./build-4.2.nix;
      base = tvp.bases.default;
      deps = {
        gnu-config = tvp.packages.gnu-config;
      };
      patches = [
        {
          file = ./patches/const-user-getters-5.5.patch;
          reason = "Preserve const UserData API by const-qualifying observational getters; GCC16 checks the template body eagerly.";
        }
      ];
      opts = {
        hardeningDisable = [ "format" ];
        cStandard = "gnu89";
        cxxStandard = "gnu++98";
      };
    };

    # GNU89 keeps implicit-int configure probes valid. The builder refreshes
    # platform detection and limits the C++ blacklist to actual GCC 1.x.
    "4.2" = {
      builder = ./build-4.2.nix;
      base = tvp.bases.default;
      deps = {
        gnu-config = tvp.packages.gnu-config;
      };
      opts = {
        hardeningDisable = [ "format" ];
        cStandard = "gnu89";
        cxxStandard = "gnu++98";
      };
    };
  };

  inherit (tvpLib.packages) merge mkTable;

  versionTable = merge {
    "4" = mkTable (import ./4.nix { inherit defs; });
    "5" = mkTable (import ./5.nix { inherit defs; });
    "6" = mkTable (import ./6.nix { inherit defs; });
  };

  pname = "ncurses";

  packageArgs = {
    testDeps.pkg-config = tvp.packages.pkg-config;
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname;
    inherit versionTable;

    extraArgs = {
      mkTests =
        ncurses:
        import ./tests {
          inherit pkgs tvpLib ncurses;
          pkg-config = ncurses.tvp.declaredTestDependencies.pkg-config;
        };
    };

    packageMeta = {
      upstream = {
        type = "directory-index";
        url = "https://mirrors.kernel.org/gnu/ncurses/";
        pattern = "ncurses-[0-9][^\"]*\\.tar\\.gz";

        normalise =
          file:
          if pkgs.lib.hasPrefix "ncurses-" file && pkgs.lib.hasSuffix ".tar.gz" file then
            pkgs.lib.removeSuffix ".tar.gz" (pkgs.lib.removePrefix "ncurses-" file)
          else
            null;

        include = version: builtins.match "[0-9].*" version != null;
      };
    };
  };

  # Complete legacy call: table, factories, source construction and test routing.
  constructionRecipe = packageArgs;
  candidate = import ../../../bases/source-gnu { };
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  constructionTool =
    name:
    tvpLib.packages.withConstraint {
      category = "construction";
      reason = "Retained source-GNU ${name} is an explicit build-only host generation, independent of these target libraries and commands.";
    } candidate.tools.${name};
  ownedDefs = tvpLib.packages.mkDefs {
    "6.6" = {
      constructor = tvp.builder;
      builder = ./native/build-6.6.nix;
      base = candidate.base;
      source =
        { version, sha256 }:
        import <nix/fetchurl.nix> {
          url = "https://mirrors.kernel.org/gnu/ncurses/ncurses-${version}.tar.gz";
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
      deps = {
        bash = constructionTool "bash";
        coreutils = constructionTool "coreutils";
        gnumake = constructionTool "make";
        gnutar = constructionTool "tar";
        python = constructionTool "python";
        binutils = constructionTool "binutils";
        patchelf = constructionTool "patchelf";
        sed = constructionTool "sed";
        grep = constructionTool "grep";
        gawk = constructionTool "gawk";
        diffutils = constructionTool "diffutils";
        findutils = constructionTool "findutils";
        gzip = constructionTool "gzip";
        pkgConfig = constructionTool "pkgConfig";
      };
    };
  };
  ordinaryDefs = import ./ordinary {
    inherit
      tvp
      tvpLib
      candidate
      constructionTool
      ;
    inherit (pkgs) fetchurl;
  };
  publicArgs = packageArgs // {
    versionTable = versionTable // {
      "6.0" = versionTable."6.0" // {
        def = if native then ordinaryDefs."6.0" else versionTable."6.0".def;
      };
      "6.1" = versionTable."6.1" // {
        def = if native then ordinaryDefs."6.0" else versionTable."6.1".def;
      };
      "6.2" = versionTable."6.2" // {
        def = if native then ordinaryDefs."6.2" else versionTable."6.2".def;
      };
      "6.3" = versionTable."6.3" // {
        def = if native then ordinaryDefs."6.2" else versionTable."6.3".def;
      };
      "6.4" = versionTable."6.4" // {
        def = if native then ordinaryDefs."6.4" else versionTable."6.4".def;
      };
      "6.5" = versionTable."6.5" // {
        def = if native then ordinaryDefs."6.4" else versionTable."6.5".def;
      };

      "6.6" = versionTable."6.6" // {
        def = if native then ownedDefs."6.6" else versionTable."6.6".def;
      };
    };
    extraArgs.mkTests =
      package:
      if package ? specification && package.specification ? cStandard then
        import ./tests/ordinary.nix {
          inherit
            pkgs
            tvpLib
            package
            tvp
            ;
        }
      else if package ? testContext then
        import ./tests/native-default.nix { inherit pkgs tvpLib package; }
      else
        constructionRecipe.extraArgs.mkTests package;
  };
  canonical = tvpLib.packages.mkVersions publicArgs;

in
{
  recipes.${pname} = publicArgs // {
    inherit constructionRecipe;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases {
    lines = [ "6_4" ];
    inherit
      pname
      versionTable
      canonical
      ;
  };
}

{ pkgs, tvp }:
let
  tvpLib = tvp.lib;

  defs = tvpLib.packages.mkDefs {
    "2.0" = {
      builder = ./build-2.0.nix;
      # gcc 10 made -fno-common the default, and these releases declare globals
      # as tentative definitions in a header, so every object file defines them.
      # The code was correct for its era; the compiler moved.
      base = tvp.bases.gcc9;
      deps = {
        ncurses = tvp.packages.ncurses_6;
      };
    };

    "2.1" = {
      builder = ./build-2.0.nix;
      base = tvp.bases.default;
      # The configure probes and empty parameter lists require pre-C23 C.
      opts = {
        cStandard = "gnu89";
        # readline.h defines rl_dispatching in every library object.
        commonSymbols = true;
      };
      deps = {
        ncurses = tvp.packages.ncurses_6;
      };
    };

    "2.2.1" = {
      builder = ./build-2.0.nix;
      base = tvp.bases.default;
      # Old configure/termcap declarations require the original C dialect.
      # 8.3 replaces the empty prototypes; keep its newer defaults unchanged.
      opts.cStandard = "gnu89";
      deps = {
        ncurses = tvp.packages.ncurses_6;
      };
    };

    "2.2" = {
      builder = ./build-2.0.nix;
      base = tvp.bases.default;
      # Old configure/termcap declarations require the original C dialect.
      # 8.3 replaces the empty prototypes; keep its newer defaults unchanged.
      opts.cStandard = "gnu89";
      deps = {
        ncurses = tvp.packages.ncurses_6;
      };
      patches = [
        {
          file = ./patches/2.2-install-clobbers-libreadline.patch;
          reason = "2.2's install target backs up libreadline.a under libhistory's name, destroying the libreadline.a it installed three lines earlier, so the package ships with no readline library at all. Corrected upstream in 2.2.1.";
        }
      ];
    };

    "4.0" = {
      builder = ./build-4.0.nix;
      base = tvp.bases.default;
      # Old configure/termcap declarations require the original C dialect.
      # 8.3 replaces the empty prototypes; keep its newer defaults unchanged.
      opts.cStandard = "gnu89";
      deps = {
        ncurses = tvp.packages.ncurses_6;
        automake = tvp.packages.automake_1;
      };
    };

    "4.3" = {
      builder = ./build-4.3.nix;
      base = tvp.bases.default;
      # Old configure/termcap declarations require the original C dialect.
      # 8.3 replaces the empty prototypes; keep its newer defaults unchanged.
      opts.cStandard = "gnu89";
      deps = {
        ncurses = tvp.packages.ncurses_6;
      };
    };
    "8.3" = {
      builder = ./build-4.3.nix;
      base = tvp.bases.default;
      deps.ncurses = tvp.packages.ncurses_6;
    };

  };

  inherit (tvpLib.packages) merge mkTable;

  versionTable = merge {
    "2" = mkTable (import ./2.nix { inherit defs; });
    "4" = mkTable (import ./4.nix { inherit defs; });
    "5" = mkTable (import ./5.nix { inherit defs; });
    "6" = mkTable (import ./6.nix { inherit defs; });
    "7" = mkTable (import ./7.nix { inherit defs; });
    "8" = mkTable (import ./8.nix { inherit defs; });
  };

  pname = "readline";

  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname;
    inherit versionTable;

    extraArgs = {
      mkTests = pkgs.lib.makeOverridable (
        { pkgs }:
        readline:
        import ./tests {
          inherit pkgs tvpLib readline;
        }
      ) { inherit pkgs; };
    };

    packageMeta = {
      upstream = {
        type = "directory-index";
        url = "https://mirrors.kernel.org/gnu/readline/";
        pattern = "readline-[0-9][^\"]*\\.tar\\.gz";

        normalise =
          file:
          if pkgs.lib.hasPrefix "readline-" file && pkgs.lib.hasSuffix ".tar.gz" file then
            pkgs.lib.removeSuffix ".tar.gz" (pkgs.lib.removePrefix "readline-" file)
          else
            null;

        # The directory also carries documentation-only tarballs named
        # readline-4.2-doc.tar.gz, which are not releases of the library.
        include =
          version:
          builtins.match "[0-9].*" version != null
          && !(
            pkgs.lib.hasSuffix "-doc" version
            || pkgs.lib.hasInfix "alpha" version
            || pkgs.lib.hasInfix "beta" version
            || pkgs.lib.hasInfix "-rc" version
          );
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
    "8.3" = {
      constructor = tvp.builder;
      builder = ./native/build-8.3.nix;
      base = candidate.base;
      source =
        { version, sha256 }:
        import <nix/fetchurl.nix> {
          url = "https://mirrors.kernel.org/gnu/readline/readline-${version}.tar.gz";
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
        pkgConfig = constructionTool "pkgConfig";
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
        ncurses = tvp.packages.ncurses_6;
      };
    };
  };
  publicArgs = packageArgs // {
    versionTable = versionTable // {
      "8.3" = versionTable."8.3" // {
        def = if native then ownedDefs."8.3" else versionTable."8.3".def;
      };
    };
    extraArgs.mkTests =
      package:
      if package ? testContext then
        import ./tests/native-default.nix { inherit pkgs tvpLib package; }
      else
        constructionRecipe.extraArgs.mkTests package;
  };
  canonical = tvpLib.packages.mkVersions publicArgs;
  variants = tvpLib.packages.mkVariants (
    constructionRecipe
    // {
      inherit pkgs;
      profiles.ncurses64 = {
        base = tvp.bases.default;
        versions."8.3".deps.ncurses = tvp.lib.packages.withConstraint {
          reason = "Named ncurses64 profile preserves its documented Ncurses 6.4 public WINDOW/header contract; ordinary canonical Readline follows the current ABI line.";
        } tvp.packages.ncurses_6_4;
      };
    }
  );

in
{
  recipes.${pname} = publicArgs // {
    inherit constructionRecipe;
  };
  inherit canonical variants;
  aliases = tvpLib.packages.mkAliases {
    lines = [ "6_2" ];
    inherit
      pname
      versionTable
      canonical
      ;
  };
}

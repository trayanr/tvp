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

in
packageArgs

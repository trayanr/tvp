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
        ncurses = tvp.packages.ncurses_6_6;
      };
    };

    # 2.2.1 stays on the default base: only 2.0 and 2.1 rely on tentative
    # definitions that gcc 10 stopped merging.
    "2.2.1" = {
      builder = ./build-2.0.nix;
      base = tvp.bases.gcc13;
      deps = {
        ncurses = tvp.packages.ncurses_6_6;
      };
    };

    "2.2" = {
      builder = ./build-2.0.nix;
      base = tvp.bases.gcc13;
      deps = {
        ncurses = tvp.packages.ncurses_6_6;
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
      base = tvp.bases.gcc13;
      deps = {
        ncurses = tvp.packages.ncurses_6_6;
      };
    };

    "4.2a" = {
      builder = ./build-4.2a.nix;
      base = tvp.bases.gcc13;
      deps = {
        ncurses = tvp.packages.ncurses_6_6;
      };
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

  canonical = tvpLib.packages.mkVersions {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    pname = "readline";
    inherit versionTable;

    extraArgs = {
      mkTests =
        readline:
        import ./tests {
          inherit pkgs tvpLib readline;
        };
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

  # No `readline_8_3`: upstream ships a release literally called 8.3.
  aliases = {
    readline_8 = canonical.readline_8_3;
    readline = canonical.readline_8_3;
  };
in
canonical // tvpLib.packages.checkAliases { inherit canonical aliases; }

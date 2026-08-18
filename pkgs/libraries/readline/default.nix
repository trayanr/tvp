{ pkgs, tvp }:
let
  tvpLib = tvp.lib;

  defs = {
    "8.0" = {
      builder = ./build-8.0.nix;
      base = tvp.bases.gcc13;
      deps = {
        ncurses = tvp.packages.ncurses_6_6;
      };
    };
  };

  versionTable = tvpLib.packages.mkTable (import ./8.nix { inherit defs; });

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
        url = "https://ftp.gnu.org/gnu/readline/";
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

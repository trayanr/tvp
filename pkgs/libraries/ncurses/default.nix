{ pkgs, tvp }:
let
  tvpLib = tvp.lib;

  defs = tvpLib.packages.mkDefs {
    "6.2" = {
      builder = ./build-6.2.nix;
      base = tvp.bases.gcc13;
      deps = {
        pkg-config = tvp.packages."pkg-config_0_29_2";
      };
    };
  };

  versionTable = tvpLib.packages.mkTable (import ./6.nix { inherit defs; });

  canonical = tvpLib.packages.mkVersions {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    pname = "ncurses";
    inherit versionTable;

    extraArgs = {
      mkTests =
        ncurses:
        import ./tests {
          inherit pkgs tvpLib ncurses;
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

  aliases = {
    ncurses_6 = canonical.ncurses_6_6;
    ncurses = canonical.ncurses_6_6;
  };
in
canonical // tvpLib.packages.checkAliases { inherit canonical aliases; }

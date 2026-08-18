{ pkgs, tvp }:
let
  tvpLib = tvp.lib;

  versionTable = tvpLib.packages.merge {
    "6" = import ./6.nix { inherit pkgs tvp; };
  };

  canonical = tvpLib.packages.mkVersions {
    inherit (pkgs) callPackage;
    pname = "ncurses";
    inherit versionTable;
    defaultBase = tvp.bases.default;

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
        url = "https://ftp.gnu.org/gnu/ncurses/";
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

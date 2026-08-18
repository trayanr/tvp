{ pkgs, tvp }:
let
  tvpLib = tvp.lib;

  versionTable = tvpLib.packages.merge {
    "1" = import ./1.nix { inherit pkgs tvp; };
  };

  canonical = tvpLib.packages.mkVersions {
    inherit (pkgs) callPackage;
    pname = "m4";
    inherit versionTable;
    defaultBase = tvp.bases.default;

    extraArgs = {
      mkTests =
        m4:
        import ./tests {
          inherit pkgs tvpLib m4;
        };
    };

    packageMeta = {
      upstream = {
        type = "directory-index";
        url = "https://ftp.gnu.org/gnu/m4/";
        pattern = "m4-[0-9][^\"]*\\.tar\\.gz";

        normalise =
          file:
          if pkgs.lib.hasPrefix "m4-" file && pkgs.lib.hasSuffix ".tar.gz" file then
            pkgs.lib.removeSuffix ".tar.gz" (pkgs.lib.removePrefix "m4-" file)
          else
            null;

        include = version: builtins.match "[0-9].*" version != null;
      };
    };
  };

  aliases = {
    m4_1_4 = canonical.m4_1_4_21;
    m4_1 = canonical.m4_1_4_21;
    m4 = canonical.m4_1_4_21;
  };
in
canonical // tvpLib.packages.checkAliases { inherit canonical aliases; }

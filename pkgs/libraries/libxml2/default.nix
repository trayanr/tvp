{ pkgs, tvp }:
let
  tvpLib = tvp.lib;

  versionTable = tvpLib.packages.merge {
    "2" = import ./2.nix { inherit pkgs tvp; };
  };

  canonical = tvpLib.packages.mkVersions {
    inherit (pkgs) callPackage;
    pname = "libxml2";
    inherit versionTable;
    defaultBase = tvp.bases.default;

    extraArgs = {
      mkTests =
        libxml2:
        import ./tests {
          inherit pkgs tvpLib libxml2;
        };
    };

    packageMeta = {
      upstream = {
        type = "git-tags";
        url = "https://gitlab.gnome.org/GNOME/libxml2";

        normalise = tag: if pkgs.lib.hasPrefix "v" tag then pkgs.lib.removePrefix "v" tag else tag;

        include =
          version:
          builtins.match "[0-9].*" version != null
          && !(
            pkgs.lib.hasInfix "alpha" version
            || pkgs.lib.hasInfix "beta" version
            || pkgs.lib.hasInfix "rc" version
          );
      };
    };
  };

  aliases = {
    libxml2_2_15 = canonical.libxml2_2_15_3;
    libxml2_2 = canonical.libxml2_2_15_3;
    libxml2 = canonical.libxml2_2_15_3;
  };
in
canonical // tvpLib.packages.checkAliases { inherit canonical aliases; }

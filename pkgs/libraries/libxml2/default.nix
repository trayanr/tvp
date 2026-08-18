{ pkgs, tvp }:
let
  tvpLib = tvp.lib;

  defs = {
    "2.12.10" = {
      builder = ./build-2.12.nix;
      base = tvp.bases.gcc13;
      deps = {
        zlib = tvp.packages.zlib_1_3_2;
        xz = pkgs.xz;
      };
    };
  };

  versionTable = tvpLib.packages.mkTable (import ./2.nix { inherit defs; });

  canonical = tvpLib.packages.mkVersions {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    pname = "libxml2";
    inherit versionTable;

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

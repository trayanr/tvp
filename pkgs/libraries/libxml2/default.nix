{ pkgs, tvp }:
let
  tvpLib = tvp.lib;

  defs = tvpLib.packages.mkDefs {
    # --with-lzma is unrecognized before 2.8.0, so xz would sit in the declared
    # graph without reaching the artifact.
    "2.7.4" = {
      builder = ./build-2.7.nix;
      base = tvp.bases.gcc13;
      deps = {
        zlib = tvp.packages.zlib_1_3_2;
      };
    };

    "2.8.0" = {
      builder = ./build-2.8.nix;
      base = tvp.bases.gcc13;
      deps = {
        zlib = tvp.packages.zlib_1_3_2;
        xz = pkgs.xz;
      };
    };

    "2.15.0" = {
      builder = ./build-2.15.nix;
      base = tvp.bases.gcc13;
      deps = {
        zlib = tvp.packages.zlib_1_3_2;
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
    libxml2_2_7 = canonical.libxml2_2_7_8;
    libxml2_2_8 = canonical.libxml2_2_8_0;
    libxml2_2_9 = canonical.libxml2_2_9_14;
    libxml2_2_10 = canonical.libxml2_2_10_4;
    libxml2_2_11 = canonical.libxml2_2_11_9;
    libxml2_2_12 = canonical.libxml2_2_12_10;
    libxml2_2_13 = canonical.libxml2_2_13_9;
    libxml2_2_14 = canonical.libxml2_2_14_6;
    libxml2_2_15 = canonical.libxml2_2_15_3;
    libxml2_2 = canonical.libxml2_2_15_3;
    libxml2 = canonical.libxml2_2_15_3;
  };
in
canonical // tvpLib.packages.checkAliases { inherit canonical aliases; }

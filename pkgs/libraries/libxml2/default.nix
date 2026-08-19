{ pkgs, tvp }:
let
  tvpLib = tvp.lib;

  defs = tvpLib.packages.mkDefs {
    # --with-lzma is unrecognized before 2.8.0, so xz would sit in the declared
    # graph without reaching the artifact.
    "2.7.4" = {
      builder = ./build-2.7.nix;
      base = tvp.bases.default;
      deps = {
        zlib = tvp.packages.zlib_1_3_2;
      };
    };

    "2.8.0" = {
      builder = ./build-2.8.nix;
      base = tvp.bases.default;
      deps = {
        zlib = tvp.packages.zlib_1_3_2;
        xz = tvp.packages.xz_5_8_3;
      };
    };

    "2.15.0" = {
      builder = ./build-2.15.nix;
      base = tvp.bases.default;
      deps = {
        zlib = tvp.packages.zlib_1_3_2;
      };
    };
  };

  versionTable = tvpLib.packages.mkTable (import ./2.nix { inherit defs; });

  pname = "libxml2";

  canonical = tvpLib.packages.mkVersions {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname;
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

in
{
  inherit canonical;
  aliases = tvpLib.packages.mkAliases {
    inherit
      pname
      versionTable
      canonical
      ;
  };
}

{ pkgs, tvp }:
let
  tvpLib = tvp.lib;

  defs = tvpLib.packages.mkDefs {
    "0.27" = {
      builder = ./build-0.27.nix;
      base = tvp.bases.default;
      deps = {
        gettext = pkgs.gettext;
      };
    };

    "0.27.1" = {
      builder = ./build-0.27.1.nix;
      base = tvp.bases.default;
      deps = { };
    };

    "0.29.2" = {
      builder = ./build-0.29.2.nix;
      base = tvp.bases.default;
      deps = { };
    };
  };

  versionTable = tvpLib.packages.mkTable (import ./0.nix { inherit defs; });

  pname = "pkg-config";

  canonical = tvpLib.packages.mkVersions {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname;
    inherit versionTable;

    extraArgs = {
      mkTests =
        pkgConfig:
        import ./tests {
          inherit pkgs tvpLib pkgConfig;
        };
    };

    packageMeta = {
      upstream = {
        type = "directory-index";
        url = "https://pkg-config.freedesktop.org/releases/";
        pattern = "pkg-config-[0-9][^\"]*\\.tar\\.gz";

        normalise =
          file:
          if pkgs.lib.hasPrefix "pkg-config-" file && pkgs.lib.hasSuffix ".tar.gz" file then
            pkgs.lib.removeSuffix ".tar.gz" (pkgs.lib.removePrefix "pkg-config-" file)
          else
            null;

        include = version: builtins.match "[0-9].*" version != null;
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

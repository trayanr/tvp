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

  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname;
    inherit versionTable;

    extraArgs = {
      mkTests = pkgs.lib.makeOverridable (
        { pkgs }:
        pkgConfig:
        import ./tests {
          inherit tvpLib pkgConfig;
          pkgs = tvpLib.tests.withBase {
            inherit pkgs;
            base.stdenv = pkgConfig.stdenv;
          };
        }
      ) { inherit pkgs; };
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

  canonical = tvpLib.packages.mkVersions packageArgs;
  variants = tvpLib.packages.mkVariants (
    packageArgs
    // {
      inherit pkgs;
      profiles = {
        gcc13 = {
          base = tvp.bases.gcc13;
          versions."0.29.2" = { };
        };
      };
    }
  );

in
{
  inherit canonical variants;
  aliases = tvpLib.packages.mkAliases {
    inherit
      pname
      versionTable
      canonical
      ;
  };
}

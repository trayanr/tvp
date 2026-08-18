{ pkgs, tvp }:
let
  tvpLib = tvp.lib;

  versionTable = tvpLib.packages.merge {
    "0" = import ./0.nix { inherit pkgs tvp; };
  };

  canonical = tvpLib.packages.mkVersions {
    inherit (pkgs) callPackage;
    pname = "pkg-config";
    inherit versionTable;
    defaultBase = tvp.bases.default;

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

  # No `pkg-config_0_29`: upstream shipped a release literally called 0.29, so
  # that name is canonical and an alias may not shadow it.
  aliases = {
    pkg-config_0 = canonical.pkg-config_0_29_2;
    pkg-config = canonical.pkg-config_0_29_2;
  };
in
canonical // tvpLib.packages.checkAliases { inherit canonical aliases; }

{ pkgs, tvp }:
let
  tvpLib = tvp.lib;

  defs = tvpLib.packages.mkDefs {
    "1.2.3" = {
      builder = ./build-1.2.3.nix;
      base = tvp.bases.gcc13;
      deps = { };
    };
  };

  versionTable = tvpLib.packages.mkTable (import ./1.nix { inherit defs; });

  canonical = tvpLib.packages.mkVersions {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    pname = "zlib";
    inherit versionTable;

    extraArgs = {
      mkTests =
        zlib:
        import ./tests {
          inherit pkgs tvpLib zlib;
        };
    };

    packageMeta = {
      upstream = {
        type = "git-tags";
        url = "https://github.com/madler/zlib";

        normalise = tag: if pkgs.lib.hasPrefix "v" tag then pkgs.lib.removePrefix "v" tag else null;

        include =
          version:
          builtins.match "[0-9].*" version != null
          && !(
            pkgs.lib.hasInfix "alpha" version
            || pkgs.lib.hasInfix "beta" version
            || pkgs.lib.hasInfix "rc" version
            || pkgs.lib.hasInfix "pre" version
          );
      };
    };
  };

  # No `zlib_1_3`: upstream shipped a release literally called 1.3, so that name
  # is canonical and an alias may not shadow it.
  aliases = {
    zlib_1 = canonical.zlib_1_3_2;
    zlib = canonical.zlib_1_3_2;
  };
in
canonical // tvpLib.packages.checkAliases { inherit canonical aliases; }

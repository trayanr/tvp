{ pkgs, tvp }:
let
  tvpLib = tvp.lib;

  defs = {
    "1.4.17" = {
      builder = ./build-1.4.19.nix;
      base = tvp.bases.gcc13;
      deps = { };
    };
  };

  versionTable = tvpLib.packages.mkTable (import ./1.nix { inherit defs; });

  canonical = tvpLib.packages.mkVersions {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    pname = "m4";
    inherit versionTable;

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
        url = "https://mirrors.kernel.org/gnu/m4/";
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

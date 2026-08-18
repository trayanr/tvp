{ pkgs, tvp }:
let
  tvpLib = tvp.lib;

  defs = tvpLib.packages.mkDefs {
    "1.23" = {
      builder = ./build-1.23.nix;
      base = tvp.bases.gcc13;
      deps = { };
    };
  };

  versionTable = tvpLib.packages.mkTable (import ./1.nix { inherit defs; });

  canonical = tvpLib.packages.mkVersions {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    pname = "gdbm";
    inherit versionTable;

    extraArgs = {
      mkTests =
        gdbm:
        import ./tests {
          inherit pkgs tvpLib gdbm;
        };
    };

    packageMeta = {
      upstream = {
        type = "directory-index";
        url = "https://mirrors.kernel.org/gnu/gdbm/";
        pattern = "gdbm-[0-9][^\"]*\\.tar\\.gz";

        normalise =
          file:
          if pkgs.lib.hasPrefix "gdbm-" file && pkgs.lib.hasSuffix ".tar.gz" file then
            pkgs.lib.removeSuffix ".tar.gz" (pkgs.lib.removePrefix "gdbm-" file)
          else
            null;

        include =
          version:
          builtins.match "[0-9].*" version != null
          && !(pkgs.lib.hasInfix "alpha" version || pkgs.lib.hasInfix "beta" version);
      };
    };
  };

  aliases = {
    gdbm_1 = canonical.gdbm_1_26;
    gdbm = canonical.gdbm_1_26;
  };
in
canonical // tvpLib.packages.checkAliases { inherit canonical aliases; }

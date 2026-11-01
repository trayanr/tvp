{ pkgs, tvp }:
let
  tvpLib = tvp.lib;

  defs = tvpLib.packages.mkDefs {
    "1.19" = {
      builder = ./build-1.9.nix;
      base = tvp.bases.default;
      deps = { };
      # src/var.c uses bool as a field name; upstream 1.25 renamed it.
      opts.cStandard = "gnu17";
    };

    "1.25" = {
      builder = ./build-1.9.nix;
      base = tvp.bases.default;
      deps = { };
    };

    # libgdbmapp uses common symbols; its old C declarations also predate C23.
    "1.11" = {
      builder = ./build-1.9.nix;
      base = tvp.bases.default;
      deps = { };
      opts = {
        cStandard = "gnu89";
        commonSymbols = true;
      };
    };

    "1.10" = {
      builder = ./build-1.9.nix;
      base = tvp.bases.default;
      deps = { };
    };

    "1.9" = {
      builder = ./build-1.9.nix;
      base = tvp.bases.default;
      deps = { };
      opts = {
        touchTestsuite = true;
      };
    };

    "1.8.0" = {
      builder = ./build-1.7.3.nix;
      base = tvp.bases.default;
      deps = { };
      opts.cStandard = "gnu89";
      patches = [
        {
          file = ./patches/1.8.0-config-sub-x86_64.patch;
          reason = "The shipped config.sub predates x86_64; accept its native CPU spelling without changing libtool's Linux rules.";
        }
      ];
    };

    "1.8.1" = {
      builder = ./build-1.7.3.nix;
      base = tvp.bases.default;
      deps = { };
      opts.cStandard = "gnu89";
    };

    "1.7.3" = {
      builder = ./build-1.7.3.nix;
      base = tvp.bases.default;
      deps = { };
      opts.cStandard = "gnu89";
      patches = [
        {
          file = ./patches/1.7.3-install-compat-unbalanced-paren.patch;
          reason = "install-compat writes 100 1 26 57 100 131 989 991srcdir/ndbm.h — an unbalanced paren make expands to nothing, so the target installs no ndbm.h at all.";
        }
      ];
    };
  };

  versionTable = tvpLib.packages.mkTable (import ./1.nix { inherit defs; });

  pname = "gdbm";

  canonical = tvpLib.packages.mkVersions {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname;
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

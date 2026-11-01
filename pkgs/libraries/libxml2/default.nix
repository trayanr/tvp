{ pkgs, tvp }:
let
  tvpLib = tvp.lib;

  defs = tvpLib.packages.mkDefs {
    # --with-lzma is unrecognized before 2.8.0, so xz would sit in the declared
    # graph without reaching the artifact.
    "2.7.4" = {
      builder = ./build-2.7.nix;
      base = tvp.bases.default;
      # Old weak pthread declarations use (), requiring pre-C23 semantics;
      # GNU89 also retains the original pointer-conversion diagnostics.
      opts.cStandard = "gnu89";
      deps = {
        zlib = tvp.packages.zlib_1;
      };
    };

    "2.8.0" = {
      builder = ./build-2.8.nix;
      base = tvp.bases.default;
      # Old weak pthread declarations use (), requiring pre-C23 semantics;
      # GNU89 also retains the original pointer-conversion diagnostics.
      opts.cStandard = "gnu89";
      deps = {
        zlib = tvp.packages.zlib_1;
        xz = tvp.packages.xz_5;
      };
    };

    "2.9.5" = {
      builder = ./build-2.8.nix;
      base = tvp.bases.default;
      deps = {
        zlib = tvp.packages.zlib_1;
        xz = tvp.packages.xz_5;
      };
    };

    "2.15.0" = {
      builder = ./build-2.15.nix;
      base = tvp.bases.default;
      deps = {
        zlib = tvp.packages.zlib_1;
      };
    };

    "2.15.4" = {
      builder = ./build-2.15.4.nix;
      base = tvp.bases.default;
      deps = {
        zlib = tvp.packages.zlib_1;
        pkg-config = tvp.packages.pkg-config;
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
    testDeps = {
      pkg-config = tvp.packages.pkg-config;
      gzip = tvp.packages.gzip;
      xz = tvp.packages.xz;
    };

    extraArgs = {
      mkTests = pkgs.lib.makeOverridable (
        { pkgs }:
        libxml2:
        import ./tests {
          inherit pkgs tvpLib libxml2;
          inherit (libxml2.tvp.declaredTestDependencies) pkg-config gzip xz;
        }
      ) { inherit pkgs; };
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

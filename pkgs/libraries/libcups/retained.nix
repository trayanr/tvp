{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "2.4.20" = {
      builder = ./build-2.4.20.nix;
      base = tvp.bases.default;
      deps = {
        dnssd =
          tvpLib.packages.withConstraint
            {
              category = "construction";
              reason = "Retained libdns_sd counterpart preserves the complete pre-migration libcups profile and public variant identities.";
            }
            (
              (tvpLib.packages.mkVersions
                (import ../libdns_sd { inherit pkgs tvp; }).recipes.libdns_sd.constructionRecipe
              ).libdns_sd_2881_120_11
            );
        pkg-config = tvp.packages.pkg-config;
        openssl = tvp.packages.openssl;
        zlib = tvp.packages.zlib_1;
        patchelf = tvp.packages.patchelf;
      };
    };
  };
  pname = "libcups";
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."2.4.20";
      releases."2.4.20" = "sha256-q02c1/PlgGAJHSsklyIj1kAWdfEcSbZav09u8x3qIv8=";
    }
  ];
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests =
      package:
      import ./tests {
        inherit tvpLib package;
        pkgs = tvpLib.tests.withBase {
          inherit pkgs;
          base.stdenv = package.stdenv;
        };

      };
  };
in
packageArgs

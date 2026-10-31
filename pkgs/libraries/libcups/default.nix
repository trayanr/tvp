{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "2.4.20" = {
      builder = ./build-2.4.20.nix;
      base = tvp.bases.default;
      deps = {
        dnssd = tvp.packages.libdns_sd;
        pkg-config = tvp.packages.pkg-config;
        openssl = tvp.packages.openssl_3;
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
  canonical = tvpLib.packages.mkVersions {
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
{
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

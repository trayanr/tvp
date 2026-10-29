{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "8.23.0" = {
      builder = ./build-8.23.0.nix;
      base = tvp.bases.default;
      deps = {
        pkg-config = tvp.packages.pkg-config_0_29_2;
        patchelf = tvp.packages.patchelf_0_19_2;
        perl = tvp.packages.perl_5_44_0;
        python = tvp.packages.python_3_12_16;
        openssl = tvp.packages.openssl_3_6_3;
        zlib = tvp.packages.zlib_1_3_2;
        zstd = tvp.packages.zstd_1_5_6;
        nghttp2 = tvp.packages.nghttp2_1_70_0;
        ca-certificates = tvp.packages.ca-certificates_2026_10_20;
      };
      opts.configureOptions = [
        "--disable-ldap"
        "--disable-ldaps"
        "--disable-ares"
        "--without-brotli"
        "--without-libpsl"
        "--without-libidn2"
        "--without-libssh2"
        "--without-libssh"
        "--without-gssapi"
        "--without-nghttp3"
        "--without-ngtcp2"
        "--without-quiche"
      ];
    };
  };
  pname = "curl";
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."8.23.0";
      releases."8.23.0" = "sha256-4953z6Y2cIPHdqJmR/yfYztTjAbDuqc9kxolKsj3K0k=";
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

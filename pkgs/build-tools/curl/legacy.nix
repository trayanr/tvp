{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "8.23.0" = {
      builder = ./build-8.23.0.nix;
      base = tvp.bases.default;
      deps = {
        pkg-config = tvp.packages.pkg-config;
        patchelf = tvp.packages.patchelf;
        perl = tvp.packages.perl_5;
        python = tvp.packages.python_3;
        openssl = tvp.packages.openssl;
        zlib = tvp.packages.zlib_1;
        zstd = tvp.packages.zstd_1;
        nghttp2 = tvp.packages.nghttp2_1;
        ca-certificates = tvp.packages.ca-certificates;
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
  publicArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests =
      package:
      import ./tests/legacy.nix {
        inherit tvpLib package;
        pkgs = tvpLib.tests.withBase {
          inherit pkgs;
          base.stdenv = package.stdenv;
        };
      };
  };
  canonical = tvpLib.packages.mkVersions publicArgs;
in
{
  recipes.curl = publicArgs;
  inherit publicArgs canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

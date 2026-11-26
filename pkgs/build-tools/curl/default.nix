{ tvp, ... }:
let
  pname = "curl";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-8.23.0-native.nix;
        deps = {
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
      releases = {
        "8.23.0" = "sha256-4953z6Y2cIPHdqJmR/yfYztTjAbDuqc9kxolKsj3K0k=";
      };
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    packageMeta.security = {
      schema = 1;
      purl = "pkg:generic/curl";
      cpes = [
        {
          vendor = "haxx";
          product = "curl";
        }
        {
          vendor = "haxx";
          product = "libcurl";
        }
      ];
      # Query identity documented at https://google.github.io/osv.dev/post-v1-query/.
      osv = {
        ecosystem = "GIT";
        name = "https://github.com/curl/curl.git";
      };
    };
    source = tvp.lib.sources.directory {
      url = "https://curl.se/download/";
      archive = "curl-{version}.tar.gz";
      discovery = rec {
        pattern = ''href="(/download/)?curl-([0-9][A-Za-z0-9.+_-]*)\.tar\.gz"'';
        normalise =
          raw:
          let
            match = builtins.match pattern raw;
          in
          if match == null then null else builtins.elemAt match 1;
      };
    };
    tests = import ./tests;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes."curl" = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

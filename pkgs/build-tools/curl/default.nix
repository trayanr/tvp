{ tvp, ... }:
let
  pname = "curl";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-8.7.0.nix;
        deps = {
          openssl = tvp.packages.openssl_3;
          zlib = tvp.packages.zlib_1;
          zstd = tvp.packages.zstd_1;
          brotli = tvp.packages.brotli;
          nghttp2 = tvp.packages.nghttp2_1;
          openldap = tvp.packages.openldap;
          krb5 = tvp.packages.krb5;
          ca-certificates = tvp.packages.ca-certificates;
        };
        # The release tarball omitted libcurl manpage sources. Restore those
        # from the commit tagged curl-8_7_0, keeping the release Autotools files.
        opts.manualSources = import <nix/fetchurl.nix> {
          name = "curl-8.7.0-manual-sources.tar.gz";
          url = "https://codeload.github.com/curl/curl/tar.gz/72cf468d459d29e5366e416c014faaaf281dfa2d";
          sha256 = "sha256-vjFALPcc1WzRj3CFkw++vKMb/olVd62eXhYab+7ZqAg=";
        };
      };
      releases."8.7.0" = "sha256-Uj393nG/WxvV05sYnk7rbXxWAAB3b+kAYwyFbcGVQlk=";
    }
    {
      def = {
        builder = ./build-8.7.0.nix;
        deps = {
          openssl = tvp.packages.openssl_3;
          zlib = tvp.packages.zlib_1;
          zstd = tvp.packages.zstd_1;
          brotli = tvp.packages.brotli;
          nghttp2 = tvp.packages.nghttp2_1;
          openldap = tvp.packages.openldap;
          krb5 = tvp.packages.krb5;
          ca-certificates = tvp.packages.ca-certificates;
        };
      };
      releases."8.7.1" = "sha256-+RJJyH9o6gDPJ8RP36WnhCPkHnG31AjlkBqYltkFxJU=";
    }
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

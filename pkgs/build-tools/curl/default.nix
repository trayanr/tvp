{ pkgs, tvp }:
let
  previous = import ./retained-index.nix { inherit pkgs tvp; };
  prior = previous.recipes."curl";
  retained = (import ./legacy.nix { inherit pkgs tvp; }).recipes.curl;
  full = tvp.baseTiers.full;
  earlier = import ../../../bases/source-gnu { };
  profileBase = full.override {
    shell = tvp.packages.bash;
    coreutils = tvp.packages.coreutils;
    standardTools = {
      gnumake = tvp.packages.gnumake;
      gnutar = tvp.packages.gnutar;
      gzip = tvp.packages.gzip;
      sed = tvp.packages.gnused;
      grep = tvp.packages.gnugrep;
      gawk = tvp.packages.gawk;
      diffutils = tvp.packages.diffutils;
      findutils = tvp.packages.findutils;
      pkg-config = tvp.packages.pkg-config;
      patchelf = tvp.packages.patchelf;
      perl = tvp.packages.perl_5;
      python = tvp.packages.python_3;
    };
  };
  pname = "curl";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-8.23.0-native.nix;
        base = profileBase;
        deps = {
          openssl = tvp.packages.openssl;
          zlib = tvp.packages.zlib_1;
          zstd = tvp.packages.zstd_1;
          nghttp2 = tvp.packages.nghttp2_1;
          ca-certificates = tvp.packages.ca-certificates;
          binutils = earlier.tools.binutils;
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
  testDeps = (prior.testDeps or { }) // { };
  rawFamily = tvp.lib.packages.mkFamily {
    inherit pname versionTable testDeps;
    packageMeta = prior.packageMeta or { };
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://curl.se/download/curl-${version}.tar.gz";
        inherit sha256;
      };
    tests = import ./tests;
  };
  family = rawFamily;
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes."curl" = family // {
    constructionRecipe = retained;
  };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

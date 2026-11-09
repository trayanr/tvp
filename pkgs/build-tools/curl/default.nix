{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  testLib = pkgs.lib;
  previous = import ./legacy.nix { inherit pkgs tvp; };
  formerRecipe = previous.publicArgs;
  candidate = import ../../../bases/source-gnu { };
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  defs = tvpLib.packages.mkDefs {
    "8.23.0" = {
      constructor = tvp.builder;
      builder = ./native/build-8.23.0.nix;
      base = candidate.base;
      helpers = { inherit tvp; };
      testContext =
        package:
        tvpLib.tests.fromPackage {
          builder = tvp.builder;
          inherit package;
        };
      deps = {
        inherit (tvp.packages)
          bash
          coreutils
          gnumake
          gnutar
          gzip
          gnused
          gnugrep
          gawk
          diffutils
          findutils
          ;
        pkg-config = tvp.packages.pkg-config;
        patchelf = tvp.packages.patchelf;
        perl = tvp.packages.perl_5;
        python = tvp.packages.python_3;
        openssl = tvp.packages.openssl;
        zlib = tvp.packages.zlib_1;
        zstd = tvp.packages.zstd_1;
        nghttp2 = tvp.packages.nghttp2_1;
        ca-certificates = tvp.packages.ca-certificates;
        binutils = tvpLib.packages.withConstraint {
          category = "construction";
          reason = "Retained source-GNU Binutils is an independently constructed ELF inspector/linker generation until ordinary Binutils is ported to the source base.";
        } candidate.tools.binutils;
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
  versionTable = formerRecipe.versionTable // {
    "8.23.0" = formerRecipe.versionTable."8.23.0" // {
      def = if native then defs."8.23.0" else formerRecipe.versionTable."8.23.0".def;
    };
  };
  publicArgs = formerRecipe // {
    inherit versionTable;
    source =
      { version, sha256 }:
      pkgs.fetchurl {
        url = "https://curl.se/download/curl-${version}.tar.gz";
        inherit sha256;
      };
    extraArgs.mkTests = testLib.makeOverridable (
      { pkgs }:
      package:
      (if package ? testContext then import ./tests else import ./tests/legacy.nix) {
        inherit tvpLib package;
        pkgs =
          if package ? testContext then
            { lib = testLib; }
          else
            tvpLib.tests.withBase {
              inherit pkgs;
              base.stdenv = package.stdenv;
            };
      }
    ) { inherit pkgs; };
  };
  canonical = tvpLib.packages.mkVersions publicArgs;
  pname = "curl";
in
{
  recipes.${pname} = publicArgs;
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

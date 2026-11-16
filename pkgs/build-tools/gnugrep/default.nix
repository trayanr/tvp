{ tvp, ... }:
let
  testBase = tvp.bases.gcc_16.full;
  locale =
    (tvp.lib.tests.fixtures.forBase {
      builder = tvp.builder;
      base = testBase;
    }).gnuLocale;
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-3.11.nix;
        deps = {
          pcre2 = tvp.packages.pcre2_10;
        };
      };
      releases = {
        "3.11" = "sha256-HbKu3eidDepCsW2VKPiUyNFdrk4ZC1muzHj1qVEnbqs=";
      };
    }
    {
      def = {
        builder = ./build-3.12.nix;
        deps = {
          pcre2 = tvp.packages.pcre2_10;
        };
      };
      releases = {
        "3.12" = "sha256-JkmyfA6Q5jLq3NdXvgbG6aT0jZQd5R58D4P/dkCKB7k=";
      };
    }
  ];
  pname = "gnugrep";
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    packageMeta.upstream = {
      type = "directory-index";
      url = "https://mirrors.kernel.org/gnu/grep/";
      # Capture the entire filename, including suffixes, before validating it.
      pattern = ''[^"<>/[:space:]]+\.tar\.[^"<>/[:space:]]+'';
      normalise =
        file:
        let
          archive = builtins.match "grep-([0-9]+(\\.[0-9]+)+)\\.tar\\.(gz|bz2|xz)" file;
        in
        if archive == null then null else builtins.head archive;
    };
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://mirrors.kernel.org/gnu/grep/grep-${version}.tar.xz";
        inherit sha256;
      };
    tests = import ./tests;
    testDeps = {
      inherit locale;
    };
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.gnugrep = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

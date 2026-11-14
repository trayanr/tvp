{ pkgs, tvp }:
let
  retained = (import ./retained { inherit pkgs tvp; }).recipes.gnugrep;
  testBase = tvp.baseTiers.full;
  testTools = testBase.standardTools;
  locale = import ../../../lib/tests/gnu-locale.nix {
    builder = tvp.builder;
    base = testBase;
    bash = testBase.shell;
    coreutils = testBase.coreutils;
    tar = testTools.gnutar;
    xz = testTools.xz;
    libc = testBase.compiler.libc;
  };
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
    inherit (retained) packageMeta;
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
  recipes.gnugrep = family // {
    constructionRecipe = retained;
  };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

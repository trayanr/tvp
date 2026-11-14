{ pkgs, tvp }:
let
  retained = (import ./retained { inherit pkgs tvp; }).recipes.gnused;
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
        builder = ./build-4.9.nix;
        deps = {
          acl = tvp.packages.acl_2;
        };
      };
      releases = {
        "4.9" = "sha256-biJrcy4c1zlGStaGK9Ghq6QteYKSLaelNRljHSSXUYE=";
      };
    }
    {
      def = {
        builder = ./build-4.10.nix;
        deps = {
          acl = tvp.packages.acl_2;
        };
      };
      releases = {
        "4.10" = "sha256-uOchgrLslqNXTimYxHt6qmTMIM4ADY6awxPMB87PKMc=";
      };
    }
  ];
  pname = "gnused";
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    inherit (retained) packageMeta;
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://mirrors.kernel.org/gnu/sed/sed-${version}.tar.xz";
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
  recipes.gnused = family // {
    constructionRecipe = retained;
  };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

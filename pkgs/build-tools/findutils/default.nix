{ pkgs, tvp }:
let
  retained = (import ./retained { inherit pkgs tvp; }).recipes.findutils;
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
        builder = ./build-4.10.0.nix;
        deps = {
          coreutils = tvp.packages.coreutils;
        };
      };
      releases = {
        "4.10.0" = "sha256-E4fgtn/yR9Kr3pmPkN+/cMFJE5Glnd/suK5ph4nwpPU=";
      };
    }
    {
      def = {
        builder = ./build-4.11.0.nix;
        deps = {
          coreutils = tvp.packages.coreutils;
        };
      };
      releases = {
        "4.11.0" = "sha256-v9GcsGzHHzNS1WfpAoTYzawCrIl3S76t8LUzsMEUMv0=";
      };
    }
  ];
  pname = "findutils";
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    inherit (retained) packageMeta;
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://mirrors.kernel.org/gnu/findutils/findutils-${version}.tar.xz";
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
  recipes.findutils = family // {
    constructionRecipe = retained;
  };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

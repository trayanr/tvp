{ pkgs, tvp }:
let
  retained = (import ./retained { inherit pkgs tvp; }).recipes.diffutils;
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
        builder = ./build-3.10.nix;
        deps = {
          coreutils = tvp.packages.coreutils;
        };
      };
      releases = {
        "3.10" = "sha256-kOXpPMck5OvhLt6A3xY0Bjx6hVaSaFkZv+YLVWyb0J4=";
        "3.11" = "sha256-pz7wX+N91YX32HBo5KBjl2BBn4EBOL11xh3aofniEx4=";
      };
    }
    {
      def = {
        builder = ./build-3.12.nix;
        deps = {
          coreutils = tvp.packages.coreutils;
        };
      };
      releases = {
        "3.12" = "sha256-fIt/n8hgkUH96pzs6FJJ0whiQ5H/Yd7a9Sj8szdyff0=";
      };
    }
  ];
  pname = "diffutils";
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    inherit (retained) packageMeta;
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://mirrors.kernel.org/gnu/diffutils/diffutils-${version}.tar.xz";
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
  recipes.diffutils = family // {
    constructionRecipe = retained;
  };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

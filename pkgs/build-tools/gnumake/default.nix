{ pkgs, tvp }:
let
  packageRecipes = tvp.lib.packages.mkDefs {
    "4.3" = {
      builder = ./build.nix;
      deps = { };
      opts.defaultCxx = "g++";
      opts.upstreamProfile = "4.3";
    };
    "4.4" = {
      builder = ./build.nix;
      deps = { };
      opts.defaultCxx = "g++";
      opts.upstreamProfile = "4.4";
    };
    "4.4.1" = {
      builder = ./build.nix;
      deps = { };
    };
  };
  versionTable = tvp.lib.packages.mkTable [
    {
      def = packageRecipes."4.3";
      releases."4.3" = "sha256-4F/d5HxffKRctpfpc4lP9PXXnhO3UO1X17Ztje/Hjhk=";
    }
    {
      def = packageRecipes."4.4";
      releases."4.4" = "sha256-WB9NToctp0s5Qch0IViYp9NYAvA3Mr3M7h1KeXkQXRg=";
    }
    {
      def = packageRecipes."4.4.1";
      releases."4.4.1" = "sha256-3Rb7HWe/q3mnL16DkHNcSePo5wtJRaFasfgd23hlj7M=";
    }
  ];
  packageMeta.upstream = {
    type = "directory-index";
    url = "https://mirrors.kernel.org/gnu/make/";
    pattern = "make-[0-9][^\"]*\\.tar\\.gz";
    normalise =
      file:
      if pkgs.lib.hasPrefix "make-" file && pkgs.lib.hasSuffix ".tar.gz" file then
        pkgs.lib.removeSuffix ".tar.gz" (pkgs.lib.removePrefix "make-" file)
      else
        null;
    include = version: builtins.match "[0-9].*" version != null;
  };
  pname = "gnumake";
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable packageMeta;
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://mirrors.kernel.org/gnu/make/make-${version}.tar.gz";
        inherit sha256;
      };
    tests = import ./tests;
    testDeps = {
      perl = tvp.packages.perl_5;
      alternateShell = tvp.packages.bash_5;
      # These are used by the shared constructor fixture, never by production.
      runtimeShell = tvp.packages.bash_5;
      compiler = tvp.baseTiers.full.compiler;
      coreutils = tvp.baseTiers.full.coreutils;
      alternateCoreutils = tvp.packages.coreutils;
      python = tvp.baseTiers.full.standardTools.python;
      grep = tvp.baseTiers.full.standardTools.grep;
      binutils = tvp.baseTiers.full.compiler.bintools;
      pkgConfig = tvp.packages.pkg-config;
      mpfr = tvp.packages.mpfr;
      sentinel = (import ../../../bases/source-gnu/tests/probes.nix { }).sentinel;
      alternateSource = (import ../../../bootstrap/source-cmake-prerequisite-tests.nix { }).alternate;
    };
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.gnumake = family // {
    constructionRecipe = (import ./legacy.nix { inherit pkgs tvp; }).recipes.gnumake.constructionRecipe;
  };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

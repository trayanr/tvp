{ tvp, ... }:
let
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        opts.defaultCxx = "g++";
        opts.upstreamProfile = "4.3";
      };
      releases."4.3" = "sha256-4F/d5HxffKRctpfpc4lP9PXXnhO3UO1X17Ztje/Hjhk=";
    }
    {
      def = {
        builder = ./build.nix;
        opts.defaultCxx = "g++";
        opts.upstreamProfile = "4.4";
      };
      releases."4.4" = "sha256-WB9NToctp0s5Qch0IViYp9NYAvA3Mr3M7h1KeXkQXRg=";
    }
    {
      def = {
        builder = ./build.nix;
      };
      releases."4.4.1" = "sha256-3Rb7HWe/q3mnL16DkHNcSePo5wtJRaFasfgd23hlj7M=";
    }
  ];

  pname = "gnumake";
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.directory {
      url = "https://mirrors.kernel.org/gnu/make/";
      archive = "make-{version}.tar.gz";
      discovery = {

        pattern = "make-[0-9][^\"]*\\.tar\\.gz";
        normalise = tvp.lib.versions.fromArchiveName {
          prefix = "make-";
          suffixes = [ ".tar.gz" ];
        };
        include = version: builtins.match "[0-9].*" version != null;
      };
    };
    tests = import ./tests;
    testDeps = {
      perl = tvp.packages.perl_5;
      alternateShell = tvp.packages.bash_5;
      # These are used by the shared constructor fixture, never by production.
      runtimeShell = tvp.packages.bash_5;
      compiler = tvp.bases.gcc_16.full.compiler;
      coreutils = tvp.bases.gcc_16.full.coreutils;
      alternateCoreutils = tvp.packages.coreutils;
      python = tvp.bases.gcc_16.full.tools.python;
      grep = tvp.bases.gcc_16.full.tools.grep;
      binutils = tvp.bases.gcc_16.full.compiler.bintools;
      pkgConfig = tvp.packages.pkg-config;
      mpfr = tvp.packages.mpfr;
      sentinel = tvp.lib.tests.fixtures.sentinel;
      alternateSource = tvp.lib.tests.fixtures.alternateSource;
    };
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.gnumake = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

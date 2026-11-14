{ pkgs, tvp }:
let
  previous = import ./retained-index.nix { inherit pkgs tvp; };
  prior = previous.recipes."coreutils";
  retained = prior.constructionRecipe or prior;
  earlier = import ../../../bases/source-gnu { };
  full = tvp.baseTiers.full;
  profileBase = full.override {
    shell = earlier.tools.bash;
    coreutils = earlier.tools.coreutils;
    standardTools = {
      gnumake = earlier.tools.make;
      gnutar = earlier.tools.tar;
      xz = earlier.tools.xz;
      gzip = earlier.tools.gzip;
      python = earlier.tools.python;
      perl = earlier.tools.perl;
      patchelf = earlier.tools.patchelf;
      sed = earlier.tools.sed;
      grep = earlier.tools.grep;
      gawk = earlier.tools.gawk;
      diffutils = earlier.tools.diffutils;
      findutils = earlier.tools.findutils;
    };
  };
  pname = "coreutils";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-9.5-current.nix;
        base = profileBase;
        deps = {
          binutils = earlier.tools.binutils;
          gmp = tvp.packages.gmp_6;
          acl = tvp.packages.acl_2;
          timezoneData = tvp.lib.packages.withConstraint {
            category = "artifact";
            reason = "Build-only zoneinfo data oracle for upstream gnulib Europe/Paris tests; no executable or runtime ownership claim.";
          } pkgs.tzdata;
        };
      };
      releases = {
        "9.5" = "sha256-zTKO3qyS9qZl3p8yPJO3Eq8YWLwuDYjz9xAEaUcKG4o=";
      };
    }
  ];
  testDeps = (prior.testDeps or { }) // {
    locale = import ../../../lib/tests/gnu-locale.nix {
      builder = tvp.builder;
      base = earlier.base;
      inherit (earlier.tools)
        bash
        coreutils
        tar
        xz
        ;
      libc = earlier.toolchain.libc;
    };
  };
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable testDeps;
    packageMeta = prior.packageMeta or { };
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://mirrors.kernel.org/gnu/coreutils/coreutils-${version}.tar.xz";
        inherit sha256;
      };
    tests = import ./tests;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes."coreutils" = family // {
    constructionRecipe = retained;
  };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

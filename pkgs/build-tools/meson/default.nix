{ pkgs, tvp }:
let
  previous = import ./retained-index.nix { inherit pkgs tvp; };
  prior = previous.recipes."meson";
  retained = prior.constructionRecipe or prior;
  earlier = import ../../../bases/source-gnu { };
  full = tvp.baseTiers.full;
  profileBase = full.override {
    shell = tvp.packages.bash_5;
    coreutils = earlier.tools.coreutils;
    standardTools = {
      python = earlier.tools.python;
      gnutar = earlier.tools.tar;
      gzip = earlier.tools.gzip;
      findutils = earlier.tools.findutils;
      patch = earlier.tools.patch;
      ninja = tvp.packages.ninja;
      cmake = tvp.packages.cmake;
      pkg-config = tvp.packages.pkg-config;
    };
  };
  pname = "meson";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-1.11.1-current.nix;
        base = profileBase;
        deps = {
          python = tvp.packages.python_3;
          # Runtime discovery providers are real package dependencies.
          ninja = tvp.packages.ninja;
          cmake = tvp.packages.cmake;
          pkg-config = tvp.packages.pkg-config;
        };
        patches = [
          {
            file = ./patches/store-rpaths.patch;
            reason = "Retain immutable store library RPATHs when installing native consumers.";
          }
        ];
      };
      releases = {
        "1.11.1" = "sha256-Z4iuKZl5ZD+NhBvK9kNSVYQ2yuRaA1UUijruzPeROGY=";
        "1.11.2" = "sha256-aY/q4GnO8+zU16rygdffNZvfz1VamhVkOD07kT+opzY=";
        "1.12.0" = "sha256-iK/gwg5SAwIYkkrDfQyBxZtLXzrjdSyMbXRwx9NliGw=";
      };
    }
    {
      def = {
        builder = ./build-1.12.1-current.nix;
        base = profileBase;
        deps = {
          python = tvp.packages.python_3;
          # Runtime discovery providers are real package dependencies.
          ninja = tvp.packages.ninja;
          cmake = tvp.packages.cmake;
          pkg-config = tvp.packages.pkg-config;
        };
        patches = [
          {
            file = ./patches/store-rpaths.patch;
            reason = "Retain immutable store library RPATHs when installing native consumers.";
          }
        ];
      };
      releases = {
        "1.12.1" = "sha256-qwpsoJ+O9wxWTIJB+1ojlXiGoLU/tYQSteB+rwfbp0M=";
      };
    }
  ];
  testDeps = (prior.testDeps or { }) // {
    zlib = tvp.packages.zlib_1;
    pkgConfig = tvp.packages.pkg-config;
    mpfr = tvp.packages.mpfr;
    sentinel = (import ../../../bases/source-gnu/tests/probes.nix { }).sentinel;
    alternateSource = (import ../../../bootstrap/source-cmake-prerequisite-tests.nix { }).alternate;
  };
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable testDeps;
    packageMeta = prior.packageMeta or { };
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://github.com/mesonbuild/meson/releases/download/${version}/meson-${version}.tar.gz";
        inherit sha256;
      };
    tests = import ./tests;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes."meson" = family // {
    constructionRecipe = retained;
  };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

{ tvp, ... }:
let
  pname = "meson";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-1.11.1-current.nix;
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
  testDeps = {
    zlib = tvp.packages.zlib_1;
    pkgConfig = tvp.packages.pkg-config;
    mpfr = tvp.packages.mpfr;
    sentinel = tvp.lib.tests.fixtures.sentinel;
    alternateSource = tvp.lib.tests.fixtures.alternateSource;
  };
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable testDeps;

    source = tvp.lib.sources.archive {
      url =
        version: "https://github.com/mesonbuild/meson/releases/download/${version}/meson-${version}.tar.gz";
      discovery = {
        type = "git-tags";
        url = "https://github.com/mesonbuild/meson.git";
        normalise = tag: tag;
        include = version: builtins.match "[0-9]+(\\.[0-9]+)*" version != null;
      };
    };
    tests = import ./tests;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes."meson" = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

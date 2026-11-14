{ pkgs, tvp }:
let
  previous = import ./retained-index.nix { inherit pkgs tvp; };
  prior = previous.recipes."file";
  retained = prior.constructionRecipe or prior;
  full = tvp.baseTiers.full;
  earlier = import ../../../bases/source-gnu { };
  profileBase = full.override {
    shell = tvp.packages.bash_5;
    coreutils = tvp.packages.coreutils_9;
    standardTools = {
      python = earlier.tools.python;
      patchelf = earlier.tools.patchelf;
      gnumake = tvp.packages.gnumake_4;
      gnutar = tvp.packages.gnutar_1;
      gzip = tvp.packages.gzip_1;
      findutils = tvp.packages.findutils_4;
      sed = tvp.packages.gnused_4;
      grep = tvp.packages.gnugrep_3;
      gawk = tvp.packages.gawk_5;
      diffutils = tvp.packages.diffutils_3;
    };
  };
  pname = "file";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-5.45-native.nix;
        base = profileBase;
        deps = {
          zlib = tvp.packages.zlib_1;
          xz = tvp.packages.xz_5;
          bzip2 = tvp.packages.bzip2_1;
          zstd = tvp.packages.zstd_1;
          binutils = earlier.tools.linker;
        };
      };
      releases = {
        "5.45" = "sha256-/Jf1ECm7DiyfTjv/79r2ePDgOe6HK53lwAKm0Jx4TYI=";
        "5.46" = "sha256-ycx3x8VgxUMTXtxVWvYJ1WGdvvARmX6YjOQKPXXYYIg=";
        "5.47" = "sha256-RWcv7BZctMwTWKLXa11X0ih23Ll6sWlCesOFy+HVWXo=";
      };
    }
    {
      def = {
        builder = ./build-5.48-native.nix;
        base = (
          profileBase.override {
            standardTools.gawk = tvp.lib.packages.withConstraint {
              reason = "File is used before the MPFR-dependent Python; retain the MPFR-free Gawk 4.0 build role.";
            } tvp.packages.gawk_4_0;
          }
        );
        deps = {
          zlib = tvp.packages.zlib_1;
          xz = tvp.packages.xz_5;
          bzip2 = tvp.packages.bzip2_1;
          zstd = tvp.packages.zstd_1;
          binutils = earlier.tools.linker;
        };
      };
      releases = {
        "5.48" = "sha256-7RRlaIOyOjZLQFfAVZXZMlLam8Rz0wEGUZUZ0NoUEoM=";
      };
    }
  ];
  testDeps = (prior.testDeps or { }) // {
    python = earlier.tools.python;
    sentinel = (import ../../../bases/source-gnu/tests/probes.nix { }).sentinel;
    alternateSource = (import ../../../bootstrap/source-cmake-prerequisite-tests.nix { }).alternate;
    alternateZlib = (import ../../../bootstrap/source-full-gcc-prerequisites.nix { }).zlib;
    pkgconfig = tvp.packages.pkg-config;
  };
  rawFamily = tvp.lib.packages.mkFamily {
    inherit pname versionTable testDeps;
    packageMeta = prior.packageMeta or { };
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://astron.com/pub/file/file-${version}.tar.gz";
        inherit sha256;
      };
    tests = import ./tests;
  };
  family = rawFamily;
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes."file" = family // {
    constructionRecipe = retained;
  };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

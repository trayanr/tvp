{ tvp, ... }:
let
  earlier = import ../../../bases/source-gnu { };
  pname = "file";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-5.45-native.nix;
        deps = {
          zlib = tvp.packages.zlib_1;
          xz = tvp.packages.xz_5;
          bzip2 = tvp.packages.bzip2_1;
          zstd = tvp.packages.zstd_1;
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
        deps = {
          zlib = tvp.packages.zlib_1;
          xz = tvp.packages.xz_5;
          bzip2 = tvp.packages.bzip2_1;
          zstd = tvp.packages.zstd_1;
        };
      };
      releases = {
        "5.48" = "sha256-7RRlaIOyOjZLQFfAVZXZMlLam8Rz0wEGUZUZ0NoUEoM=";
      };
    }
  ];
  testDeps = {
    python = earlier.tools.python;
    sentinel = tvp.lib.tests.fixtures.sentinel;
    alternateSource = tvp.lib.tests.fixtures.alternateSource;
    alternateZlib = (import ../../../bootstrap/source-full-gcc-prerequisites.nix { }).zlib;
    pkgconfig = tvp.packages.pkg-config;
  };
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable testDeps;
    packageMeta.upstream = {
      type = "directory-index";
      url = "https://www.astron.com/pub/file/";
      pattern = "file-[0-9]+[.][0-9]+[.]tar[.](gz|bz2|xz|Z|lz|zst)";
      normalise =
        file:
        let
          match = builtins.match "file-([0-9]+[.][0-9]+)[.]tar[.](gz|bz2|xz|Z|lz|zst)" file;
        in
        if match == null then null else builtins.head match;
      include = version: builtins.match "[0-9]+[.][0-9]+" version != null;
    };
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://astron.com/pub/file/file-${version}.tar.gz";
        inherit sha256;
      };
    tests = import ./tests;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes."file" = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

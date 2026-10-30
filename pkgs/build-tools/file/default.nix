{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "5.45" = {
      builder = ./build-5.45.nix;
      base = tvp.bases.default;
      deps = {
        zlib = tvp.packages.zlib_1_3_2;
        xz = tvp.packages.xz_5_8_3;
        bzip2 = tvp.packages.bzip2_1_0_8;
        zstd = tvp.packages.zstd_1_5_6;
      };
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."5.45";
      releases = {
        "5.45" = "sha256-/Jf1ECm7DiyfTjv/79r2ePDgOe6HK53lwAKm0Jx4TYI=";
        "5.46" = "sha256-ycx3x8VgxUMTXtxVWvYJ1WGdvvARmX6YjOQKPXXYYIg=";
        "5.47" = "sha256-RWcv7BZctMwTWKLXa11X0ih23Ll6sWlCesOFy+HVWXo=";
        "5.48" = "sha256-7RRlaIOyOjZLQFfAVZXZMlLam8Rz0wEGUZUZ0NoUEoM=";
      };
    }
  ];
  pname = "file";
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
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
    extraArgs.mkTests = package: import ./tests { inherit pkgs tvpLib package; };
  };
  canonical = tvpLib.packages.mkVersions packageArgs;

in
{
  recipes.${pname} = packageArgs;
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

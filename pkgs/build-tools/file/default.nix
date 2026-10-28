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
      releases."5.45" = "sha256-/Jf1ECm7DiyfTjv/79r2ePDgOe6HK53lwAKm0Jx4TYI=";
    }
  ];
  pname = "file";
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests = package: import ./tests { inherit pkgs tvpLib package; };
  };
  canonical = tvpLib.packages.mkVersions packageArgs;
  variants = tvpLib.packages.mkVariants (
    packageArgs
    // {
      inherit pkgs;
      profiles.gcc13 = {
        base = tvp.bases.gcc13;
        versions."5.45" = {
          deps = {
            bzip2 = tvp.variants.gcc13.bzip2_1_0_8;
            xz = tvp.variants.gcc13.xz_5_8_3;
            zlib = tvp.variants.gcc13.zlib_1_3_2;
            zstd = tvp.variants.gcc13.zstd_1_5_6;
          };
        };
      };
    }
  );

in
{
  inherit canonical variants;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

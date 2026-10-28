{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "5.2.2" = {
      builder = ./build-5.2.2.nix;
      base = tvp.bases.default;
      deps = {
        gmp = tvp.packages.gmp_6_3_0;
        mpfr = tvp.packages.mpfr_4_2_1;
        readline = tvp.packages.readline_8_3;
        ncurses = tvp.packages.ncurses_6_6;
      };
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."5.2.2";
      releases."5.2.2" = "sha256-PB/OFEa0y+4c0nO9fsZLyH2J9hU3RxzT4F4zqWWiUOk=";
    }
  ];
  pname = "gawk";
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
        versions."5.2.2" = {
          deps = {
            gmp = tvp.variants.gcc13.gmp_6_3_0;
            mpfr = tvp.variants.gcc13.mpfr_4_2_1;
            ncurses = tvp.variants.gcc13.ncurses_6_6;
            readline = tvp.variants.gcc13.readline_8_3;
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

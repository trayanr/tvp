{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "1.3.1" = {
      builder = ./build-1.3.1.nix;
      base = tvp.bases.default;
      deps = {
        gmp = tvp.packages.gmp_6_3_0;
        mpfr = tvp.packages.mpfr_4_2_1;
      };
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."1.3.1";
      releases."1.3.1" = "sha256-q2QkkvXPiCt0qgy3MM1BCoHtzb7IlRg86TDnBsHHWbg=";
    }
  ];
  pname = "mpc";
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests = mpc: import ./tests { inherit pkgs tvpLib mpc; };
  };
  canonical = tvpLib.packages.mkVersions packageArgs;
  variants = tvpLib.packages.mkVariants (
    packageArgs
    // {
      inherit pkgs;
      profiles.gcc13 = {
        base = tvp.bases.gcc13;
        versions."1.3.1" = {
          deps = {
            gmp = tvp.variants.gcc13.gmp_6_3_0;
            mpfr = tvp.variants.gcc13.mpfr_4_2_1;
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

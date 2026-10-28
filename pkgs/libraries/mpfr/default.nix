{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "4.2.1" = {
      builder = ./build-4.2.1.nix;
      base = tvp.bases.default;
      deps = {
        gmp = tvp.packages.gmp_6_3_0;
      };
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."4.2.1";
      releases."4.2.1" = "sha256-J3gHNTpnJpeJlpRa8T5Sgp46vXqaW3+yeTiU4Y8fy7I=";
    }
  ];
  pname = "mpfr";
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests = mpfr: import ./tests { inherit pkgs tvpLib mpfr; };
  };
  canonical = tvpLib.packages.mkVersions packageArgs;
  variants = tvpLib.packages.mkVariants (
    packageArgs
    // {
      inherit pkgs;
      profiles.gcc13 = {
        base = tvp.bases.gcc13;
        versions."4.2.1" = {
          deps = {
            gmp = tvp.variants.gcc13.gmp_6_3_0;
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

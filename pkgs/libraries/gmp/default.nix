{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "6.3.0" = {
      builder = ./build-6.3.0.nix;
      base = tvp.bases.default;
      deps = {
        m4 = tvp.packages.m4_1_4_21;
      };
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."6.3.0";
      releases."6.3.0" = "sha256-o8K4AgG4nmhhb0rTC8Zq7kknw85Q4zkpyoGdXENTiJg=";
    }
  ];
  pname = "gmp";
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests = gmp: import ./tests { inherit pkgs tvpLib gmp; };
  };
  canonical = tvpLib.packages.mkVersions packageArgs;
  variants = tvpLib.packages.mkVariants (
    packageArgs
    // {
      inherit pkgs;
      profiles.gcc13 = {
        base = tvp.bases.gcc13;
        versions."6.3.0" = {
          deps = {
            m4 = tvp.variants.gcc13.m4_1_4_21;
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

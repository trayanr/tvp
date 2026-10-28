{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "0.20" = {
      builder = ./build-0.20.nix;
      base = tvp.bases.default;
      deps = {
        gmp = tvp.packages.gmp_6_3_0;
      };
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."0.20";
      releases."0.20" = "sha256-pVlqn7ils2XLYS5LlihzXW5n6RePrhNKgWrhlQF+d6o=";
    }
  ];
  pname = "isl";
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests = isl: import ./tests { inherit pkgs tvpLib isl; };
  };
  canonical = tvpLib.packages.mkVersions packageArgs;
  variants = tvpLib.packages.mkVariants (
    packageArgs
    // {
      inherit pkgs;
      profiles.gcc13 = {
        base = tvp.bases.gcc13;
        versions."0.20" = {
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

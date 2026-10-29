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

in
{
  recipes.${pname} = packageArgs;
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "6.9" = {
      builder = ./build-6.9.nix;
      base = tvp.bases.default;
      deps.perl = tvp.packages.perl_5_44_0;
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."6.9";
      releases."6.9" = "sha256-JPoB+5icej4oRT8Rd5kWhxN2bhGcU4HawwEV8Y8mgUk=";
    }
  ];
  pname = "linux-headers";
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
      inherit (tvpLib) platforms;
    };
    inherit pname versionTable;
    extraArgs.mkTests = headers: import ./tests { inherit pkgs tvpLib headers; };
  };
  canonical = tvpLib.packages.mkVersions packageArgs;

in
{
  recipes.${pname} = packageArgs;
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

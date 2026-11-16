{ pkgs, tvp }:
let
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
      };
      releases = {
        "2.9.0" = "sha256-HmNxhizDGZmzaMO4m0mZTwZ34bq18bK4WuN0H12AMFE=";
      };
    }
  ];
  pname = "expat";
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://github.com/libexpat/libexpat/releases/download/R_${
          pkgs.lib.replaceStrings [ "." ] [ "_" ] version
        }/expat-${version}.tar.xz";
        inherit sha256;
      };
    tests = import ./tests;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.expat = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

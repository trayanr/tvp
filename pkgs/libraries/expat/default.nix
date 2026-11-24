{ pkgs, tvp }:
let
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
      };
      releases = {
        "2.9.0" = "sha256-HmNxhizDGZmzaMO4m0mZTwZ34bq18bK4WuN0H12AMFE=";
        "2.11.0" = "sha256-YedhS2AiAcKKGJ2v7nj1vOruGSu95GqTB1L/Cc9VQvo=";
      };
    }
  ];
  pname = "expat";
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url =
        version:
        "https://github.com/libexpat/libexpat/releases/download/R_${
          pkgs.lib.replaceStrings [ "." ] [ "_" ] version
        }/expat-${version}.tar.xz";
      discovery = {
        type = "git-tags";
        url = "https://github.com/libexpat/libexpat";
        normalise =
          tag:
          if builtins.match "R_[0-9]+(_[0-9]+)+" tag == null then
            null
          else
            builtins.replaceStrings [ "_" ] [ "." ] (builtins.substring 2 (builtins.stringLength tag) tag);
      };
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

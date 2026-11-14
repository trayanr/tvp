{ pkgs, tvp }:
let
  revision = "428664896cf9e92d264976a960c76660938dffce";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        opts = {
          inherit revision;
        };
      };
      releases."2026-05-17" = "sha256-QISEaOsldatDEnX+sJQ/y5CLr7hpxADHkIMfbU+TpXk=";
    }
  ];
  pname = "gnu-config";
  retained = import ./retained { inherit pkgs tvp; };
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    inherit (retained) packageMeta;
    source =
      { sha256, ... }:
      pkgs.fetchgit {
        url = "https://https.git.savannah.gnu.org/git/config.git";
        rev = revision;
        inherit sha256;
        fetchSubmodules = false;
      };
    tests = import ./tests;
    testDeps.sentinel = (import ../../../bases/source-gnu/tests/probes.nix { }).sentinel;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.gnu-config = family // {
    constructionRecipe = retained;
  };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

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
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;

    source = tvp.lib.sources.archive {
      url = "https://https.git.savannah.gnu.org/git/config.git";
      fetch =
        { sha256, ... }:
        pkgs.fetchgit {
          url = "https://https.git.savannah.gnu.org/git/config.git";
          rev = revision;
          inherit sha256;
          fetchSubmodules = false;
        };
      discovery = {
        type = "git-head";
        # Savannah's direct HTTPS transport for the canonical config.git repository.
        url = "https://https.git.savannah.gnu.org/git/config.git";
        ref = "refs/heads/master";
        revisions."2026-05-17" = revision;
      };
    };
    tests = import ./tests;
    testDeps.sentinel = tvp.lib.tests.fixtures.sentinel;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.gnu-config = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

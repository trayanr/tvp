{ tvp, ... }:
let
  revision = "428664896cf9e92d264976a960c76660938dffce";
  repository = "https://https.git.savannah.gnu.org/git/config.git";
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
      url = repository;
      fetch =
        { sha256, ... }:
        import ./source.nix {
          inherit repository revision sha256;
          inherit (tvp.bases.default.platform) system;
          inherit (tvp.packages)
            bash
            coreutils
            git
            ca-certificates
            ;
        };
      discovery = {
        type = "git-head";
        # Savannah's anonymous Git mirror serves the canonical branch head.
        url = "git://git.git.savannah.gnu.org/config.git";
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

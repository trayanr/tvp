{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  revision = "428664896cf9e92d264976a960c76660938dffce";
  defs = tvpLib.packages.mkDefs {
    "2026-05-17" = {
      builder = ./build-2026-05-17.nix;
      base = tvp.bases.default;
      deps.bash = tvp.packages.bash;
      opts = {
        inherit revision;
      };
    };
  };
  pname = "gnu-config";
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."2026-05-17";
      releases."2026-05-17" = "sha256-QISEaOsldatDEnX+sJQ/y5CLr7hpxADHkIMfbU+TpXk=";
    }
  ];
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchgit;
    };
    inherit pname versionTable;
    extraArgs.mkTests =
      package:
      import ./tests {
        inherit tvpLib package;
        pkgs = tvpLib.tests.withBase {
          inherit pkgs;
          base.stdenv = package.stdenv;
        };
      };
    packageMeta.upstream = {
      type = "git-head";
      # Savannah's direct HTTPS transport for the canonical config.git repository.
      url = "https://https.git.savannah.gnu.org/git/config.git";
      ref = "refs/heads/master";
      revisions."2026-05-17" = revision;
    };
  };
  canonical = tvpLib.packages.mkVersions packageArgs;
in
{
  recipes.${pname} = packageArgs;
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  previous = import ./legacy.nix { inherit pkgs tvp; };
  constructionRecipe = previous.recipes.gnu-config;
  candidate = import ../../../bases/source-gnu { };
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  revision = "428664896cf9e92d264976a960c76660938dffce";
  defs = tvpLib.packages.mkDefs {
    "2026-05-17" = {
      constructor = tvp.builder;
      builder = ./build-2026-05-17.nix;
      base = candidate.base;
      helpers = {
        inherit tvp;
      };
      testContext =
        package:
        tvpLib.tests.fromPackage {
          builder = tvp.builder;
          inherit package;
        };
      deps = {
        bash = tvp.packages.bash_5;
        coreutils = tvp.packages.coreutils_9;
        sed = tvp.packages.gnused_4;
        gawk = tvp.packages.gawk_5;
        grep = tvp.packages.gnugrep_3;
      };
      opts = {
        inherit revision;
      };
    };
  };
  versionTable = constructionRecipe.versionTable // {
    "2026-05-17" = constructionRecipe.versionTable."2026-05-17" // {
      def = if native then defs."2026-05-17" else constructionRecipe.versionTable."2026-05-17".def;
    };
  };
  publicArgs = constructionRecipe // {
    inherit versionTable;
    source =
      { version, sha256 }:
      pkgs.fetchgit {
        url = "https://https.git.savannah.gnu.org/git/config.git";
        rev = revision;
        inherit sha256;
        fetchSubmodules = false;
      };
    testDeps = {
      sentinel = (import ../../../bases/source-gnu/tests/probes.nix { }).sentinel;
      diffutils = tvp.packages.diffutils_3;
    };
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      if package ? testContext then
        import ./tests/native.nix { inherit pkgs tvp package; }
      else
        import ./tests {
          inherit tvpLib package;
          pkgs = tvpLib.tests.withBase {
            inherit pkgs;
            base.stdenv = package.stdenv;
          };
        }
    ) { inherit pkgs; };
  };
  canonical = tvpLib.packages.mkVersions publicArgs;
  pname = "gnu-config";
in
{
  recipes.${pname} = publicArgs // {
    inherit constructionRecipe;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

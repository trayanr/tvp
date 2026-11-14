{ pkgs, tvp }:
let
  retained = (import ./legacy.nix { inherit pkgs tvp; }).recipes.nodejs;
  pname = "nodejs";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-owned-26.13.0.nix;
        base = (tvp.baseTiers.full.override { standardTools.ninja = tvp.packages.ninja; });
        deps = {
          python = tvp.packages.python_3;
          # Exact previous runtime shell; independent of public Bash's bashbug.
          runtimeBash = tvp.lib.packages.withConstraint {
            category = "construction";
            reason = "Retained source-GNU Bash provides the existing compiler-free Node subprocess/npm shell.";
          } tvp.baseTiers.full.shell;
          rustc = tvp.packages.rustc_1;
          cargo = tvp.packages.cargo-bootstrap_1;
          openssl = tvp.packages.openssl;
          zlib = tvp.packages.zlib_1;
        };
        patches = [
          {
            file = ./patches/store-shell.patch;
            reason = "Bind subprocess and npm shells to the explicitly selected Bash.";
          }
        ];
      };
      releases."26.13.0" = "sha256-Jj9jns+noXtJQ412zb+a/3MXnjx8t4naabkAcYQn+i4=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    packageMeta = retained.packageMeta or { };
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://nodejs.org/dist/v${version}/node-v${version}.tar.xz";
        inherit sha256;
      };
    tests = (import ./tests/provider-context.nix { inherit pkgs; });
    testDeps.shell = tvp.packages.bash_5;
  };
  # Preserve only the historical named test-factory override, lazily.
  recipe = family // {
    extraArgs = family.extraArgs // {
      mkTests = import ./tests/caller-factory.nix { inherit pkgs tvp; };
    };
  };
  canonical = tvp.lib.packages.mkVersions recipe;
in
{
  recipes.nodejs = recipe // {
    constructionRecipe = retained;
  };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  testLib = pkgs.lib;
  previous = import ./legacy.nix { inherit pkgs tvp; };
  formerRecipe = previous.publicArgs;
  constructionRecipe = previous.recipes.zstd.constructionRecipe;
  candidate = import ../../../bases/source-gnu { };
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  constructionTool =
    name:
    tvpLib.packages.withConstraint {
      category = "construction";
      reason = "Retained source-GNU ${name} is an independent build-only host generation; ordinary Python/Binutils consume Zstd and cannot construct it.";
    } candidate.tools.${name};
  defs = tvpLib.packages.mkDefs {
    "1.5.7" = {
      constructor = tvp.builder;
      builder = ./build-1.5.7.nix;
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
        inherit (tvp.packages)
          bash
          coreutils
          gnutar
          gzip
          gnumake
          gnused
          gnugrep
          diffutils
          findutils
          ;
        python = constructionTool "python";
        binutils = constructionTool "binutils";
        patchelf = constructionTool "patchelf";
        zlib = tvp.packages.zlib_1;
        xz = tvp.packages.xz_5;
      };
    };
  };
  versionTable = formerRecipe.versionTable // {
    "1.5.7" = formerRecipe.versionTable."1.5.7" // {
      def = if native then defs."1.5.7" else formerRecipe.versionTable."1.5.7".def;
    };
  };
  publicArgs = formerRecipe // {
    inherit versionTable;
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      import ./tests {
        inherit tvpLib;
        pkgs = if package ? testContext then { lib = testLib; } else pkgs;
        zstd = package;
        inherit (package.tvp.declaredTestDependencies) gzip;
      }
      // testLib.optionalAttrs (package ? edit) {
        helpers = import ./tests/helpers.nix {
          inherit package;
          inherit (package.tvp.deps) bash coreutils gnugrep;
        };
      }
    ) { inherit pkgs; };
  };
  canonical = tvpLib.packages.mkVersions publicArgs;
  pname = "zstd";
in
{
  recipes.${pname} = publicArgs // {
    inherit constructionRecipe;
  };
  inherit canonical;
  inherit (previous) variants;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

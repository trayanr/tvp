{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  testLib = pkgs.lib;
  previous = import ./legacy.nix { inherit pkgs tvp; };
  formerRecipe = previous.recipes.json-c;
  constructionRecipe = formerRecipe;
  candidate = import ../../../bases/source-gnu { };
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  constructionTool =
    name:
    tvpLib.packages.withConstraint {
      category = "construction";
      reason = "Retained source-GNU ${name} is an independent build-only host generation; ordinary Python/Binutils consume Zstd and cannot construct it.";
    } candidate.tools.${name};
  defs = tvpLib.packages.mkDefs {
    "0.19" = {
      constructor = tvp.builder;
      builder = ./native/build-0.19.nix;
      base = candidate.base;
      helpers = { inherit tvp; };
      testContext =
        package:
        tvpLib.tests.fromPackage {
          builder = tvp.builder;
          inherit package;
        };
      deps = {
        inherit (tvp.packages)
          cmake
          bash
          coreutils
          gnumake
          gnutar
          gzip
          patch
          findutils
          ;
        sed = tvp.packages.gnused;
        diffutils = tvp.packages.diffutils;
        python = constructionTool "python";
        binutils = constructionTool "binutils";
        patchelf = constructionTool "patchelf";
      };
      patches = [
        {
          file = ./patches/posix-test-byte.patch;
          reason = "Emit the same incomplete UTF-8 byte with POSIX printf instead of undeclared xxd in the upstream CLI fixture.";
        }
      ];
    };
  };
  versionTable = formerRecipe.versionTable // {
    "0.19" = formerRecipe.versionTable."0.19" // {
      def = if native then defs."0.19" else formerRecipe.versionTable."0.19".def;
    };
  };
  publicArgs = formerRecipe // {
    inherit versionTable;
    testDeps = formerRecipe.testDeps // {
      grep = tvp.packages.gnugrep;
      diffutils = tvp.packages.diffutils;
    };
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      let
        testPkgs =
          if package ? testContext then
            { lib = testLib; }
          else
            tvpLib.tests.withBase {
              inherit pkgs;
              base.stdenv = package.stdenv;
            };
      in
      import ./tests {
        inherit tvpLib package;
        pkgs = testPkgs;
        pkg-config = package.tvp.declaredTestDependencies.pkg-config;
      }
      // import ./tests/build-steps.nix {
        inherit tvpLib package;
        pkgs = testPkgs;
      }
    ) { inherit pkgs; };
  };
  canonical = tvpLib.packages.mkVersions publicArgs;
  pname = "json-c";
in
{
  recipes.${pname} = publicArgs // {
    inherit constructionRecipe;
  };
  inherit canonical;
  inherit (previous) variants;
  aliases = tvpLib.packages.mkAliases {
    inherit pname versionTable canonical;
    lines = [ "0" ];
  };
}

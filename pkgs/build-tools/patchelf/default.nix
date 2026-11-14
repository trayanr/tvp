{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  testLib = pkgs.lib;
  previous = import ./legacy.nix { inherit pkgs tvp; };
  formerRecipe = previous.publicArgs;
  candidate = import ../../../bases/source-gnu { };
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  constructionTool =
    name:
    tvpLib.packages.withConstraint {
      category = "construction";
      reason = "Retained source-GNU ${name} is an independently built host generation; Patchelf cannot finalize itself or acquire public Python/Binutils reverse-dependency cycles.";
    } candidate.tools.${name};
  defs = tvpLib.packages.mkDefs {
    "0.19.2" = {
      constructor = tvp.builder;
      builder = ./native/build-0.19.2.nix;
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
          gnumake
          gnutar
          bzip2
          gzip
          gnused
          gnugrep
          diffutils
          findutils
          ;
        gawk = tvpLib.packages.withConstraint {
          reason = "Patchelf is a build prerequisite of MPFR; Gawk 5 depends on MPFR. Select the MPFR-free Gawk 4.0 line for the build-only AWK role.";
        } tvp.packages.gawk_4_0;
        python = constructionTool "python";
        binutils = constructionTool "binutils";
        patchelf = constructionTool "patchelf";
        cxxRuntime = tvpLib.packages.withConstraint {
          category = "construction";
          reason = "The selected full source-GNU driver resolves libstdc++ and libgcc_s to this full GCC output, independently of the split runtimes used to construct the compiler.";
        } candidate.toolchain.runtime;
      };
    };
  };
  versionTable = formerRecipe.versionTable // {
    "0.19.2" = formerRecipe.versionTable."0.19.2" // {
      def = if native then defs."0.19.2" else formerRecipe.versionTable."0.19.2".def;
    };
  };
  publicArgs = formerRecipe // {
    inherit versionTable;
    extraArgs.mkTests = testLib.makeOverridable (
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
      }
      // (if package ? testContext then import ./tests/owned.nix else import ./tests/legacy-owned.nix) {
        inherit tvp tvpLib package;
        pkgs = testPkgs;
      }
    ) { inherit pkgs; };
  };
  canonical = tvpLib.packages.mkVersions publicArgs;
  pname = "patchelf";
in
{
  recipes.${pname} = publicArgs // {
    inherit (previous.recipes.patchelf) constructionRecipe constructionBuilder;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

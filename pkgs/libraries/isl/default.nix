{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  previous = import ./legacy.nix { inherit pkgs tvp; };
  retained = previous.recipes.isl;
  candidate = import ../../../bases/source-gnu { };
  constructionTools = builtins.mapAttrs (
    _: tool:
    tvpLib.packages.withConstraint {
      category = "construction";
      reason = "Retained source-GNU preparation tool; avoids a public prerequisite/toolchain cycle.";
    } tool
  ) candidate.tools;
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  definition =
    (tvpLib.packages.mkDefs {
      "0.28" = {
        constructor = tvp.builder;
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
        builder = ./native/build-0.28.nix;
        source =
          { version, sha256 }:
          import <nix/fetchurl.nix> {
            url = "https://libisl.sourceforge.io/isl-${version}.tar.xz";
            inherit sha256;
          };
        deps = {
          inherit (constructionTools)
            bash
            coreutils
            xz
            python
            binutils
            patchelf
            sed
            grep
            gawk
            diffutils
            gzip
            findutils
            ;
          gnumake = constructionTools.make;
          gnutar = constructionTools.tar;
          gmp = tvp.packages.gmp_6;
        };

      };
    })."0.28";
  versionTable = retained.versionTable // {
    "0.28" = retained.versionTable."0.28" // {
      def = if native then definition else retained.versionTable."0.28".def;
    };
  };
  publicArgs = retained // {
    inherit versionTable;
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      if package ? testContext then
        import ./tests/native.nix {
          inherit
            pkgs
            tvp
            tvpLib
            package
            ;
        }
      else
        (import ./legacy.nix { inherit pkgs tvp; }).recipes.isl.extraArgs.mkTests package
    ) { inherit pkgs; };
  };
  canonical = tvpLib.packages.mkVersions publicArgs;
  pname = "isl";
in
{
  recipes.${pname} = publicArgs // {
    constructionRecipe = retained;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

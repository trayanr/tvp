{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  previous = import ./legacy.nix { inherit pkgs tvp; };
  retained = previous.recipes.expat;
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
      "2.9.0" = {
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
        builder = ./native/build-2.9.0.nix;
        source =
          { version, sha256 }:
          import <nix/fetchurl.nix> {
            url = "https://github.com/libexpat/libexpat/releases/download/R_${
              pkgs.lib.replaceStrings [ "." ] [ "_" ] version
            }/expat-${version}.tar.xz";
            inherit sha256;
          };
        deps = {
          inherit (constructionTools)
            bash
            coreutils
            xz
            findutils
            python
            binutils
            patchelf
            cmake
            ninja
            ;
          gnutar = constructionTools.tar;
        };

      };
    })."2.9.0";
  versionTable = retained.versionTable // {
    "2.9.0" = retained.versionTable."2.9.0" // {
      def = if native then definition else retained.versionTable."2.9.0".def;
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
        retained.extraArgs.mkTests package
    ) { inherit pkgs; };
  };
  canonical = tvpLib.packages.mkVersions publicArgs;
  pname = "expat";
in
{
  recipes.${pname} = publicArgs // {
    constructionRecipe = retained;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

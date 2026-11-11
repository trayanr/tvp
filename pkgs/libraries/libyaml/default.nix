{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  previous = import ./legacy.nix { inherit pkgs tvp; };
  retained = previous.recipes.libyaml;
  candidate = import ../../../bases/source-gnu { };
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  definition =
    (tvpLib.packages.mkDefs {
      "0.2.5" = {

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
        builder = ./native/build-0.2.5.nix;
        source =
          { version, sha256 }:
          import <nix/fetchurl.nix> {
            url = "https://pyyaml.org/download/libyaml/yaml-${version}.tar.gz";
            inherit sha256;
          };
        deps = {

          inherit (candidate.tools)
            bash
            coreutils
            gzip
            python
            binutils
            patchelf
            sed
            grep
            gawk
            diffutils
            findutils
            ;
          gnumake = candidate.tools.make;
          gnutar = candidate.tools.tar;
        };
      };
    })."0.2.5";
  constructionTool =
    name:
    tvpLib.packages.withConstraint {
      category = "construction";
      reason = "Retained source-GNU ${name} is the explicit host generation, independent of the ordinary target being built.";
    } candidate.tools.${name};
  ordinaryDefs = import ./ordinary {
    inherit
      tvp
      tvpLib
      candidate
      constructionTool
      ;
    fetchurl = pkgs.fetchurl;
  };
  ordinaryRoutes = {
    "0.0.1" = "0.0.1";
    "0.1.1" = "0.1.1";
    "0.1.2" = "0.1.1";
    "0.1.3" = "0.1.1";
    "0.1.4" = "0.1.4";
    "0.1.5" = "0.1.4";
    "0.1.6" = "0.1.4";
    "0.1.7" = "0.1.4";
    "0.2.1" = "0.1.4";
    "0.2.2" = "0.1.4";
    "0.2.3" = "0.1.4";
    "0.2.4" = "0.1.4";
  };
  versionTable =
    retained.versionTable
    // (builtins.mapAttrs (
      version: start:
      retained.versionTable.${version}
      // {
        def = if native then ordinaryDefs.${start} else retained.versionTable.${version}.def;
      }
    ) ordinaryRoutes)
    // {
      "0.2.5" = retained.versionTable."0.2.5" // {
        def = if native then definition else retained.versionTable."0.2.5".def;
      };
    };
  defaultTestPkgs = pkgs;
  publicArgs = retained // {
    inherit versionTable;
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      args@{
        pkgs ? defaultTestPkgs,
      }:
      package:
      if args ? pkgs then
        (retained.extraArgs.mkTests.override { inherit pkgs; }) package
      else if package ? testContext && builtins.hasAttr package.version ordinaryRoutes then
        import ./tests/ordinary.nix {
          inherit
            pkgs
            tvp
            tvpLib
            package
            ;
        }
      else if package ? testContext then
        import ./tests/native.nix {
          inherit
            pkgs
            tvp
            tvpLib
            package
            ;
        }
      else
        (retained.extraArgs.mkTests.override { inherit pkgs; }) package
    ) { };
  };
  canonical = tvpLib.packages.mkVersions publicArgs;
  pname = "libyaml";
in
{
  recipes.${pname} = publicArgs // {
    constructionRecipe = retained;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

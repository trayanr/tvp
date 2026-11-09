{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  previous = import ./legacy.nix { inherit pkgs tvp; };
  retained = previous.recipes.bundler;
  candidate = import ../../../bases/source-gnu { };
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  definition =
    (tvpLib.packages.mkDefs {
      "2.5.20" = {

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
        builder = ./native/build-2.5.20.nix;
        source =
          { version, sha256 }:
          import <nix/fetchurl.nix> {
            url = "https://rubygems.org/gems/bundler-${version}.gem";
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
            findutils
            ;
          ruby = tvp.packages.ruby_3;
        };
      };
    })."2.5.20";
  versionTable = retained.versionTable // {
    "2.5.20" = retained.versionTable."2.5.20" // {
      def = if native then definition else retained.versionTable."2.5.20".def;
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
        (retained.extraArgs.mkTests.override { inherit pkgs; }) package
    ) { inherit pkgs; };
  };
  canonical = tvpLib.packages.mkVersions publicArgs;
  pname = "bundler";
in
{
  recipes.${pname} = publicArgs // {
    constructionRecipe = retained;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

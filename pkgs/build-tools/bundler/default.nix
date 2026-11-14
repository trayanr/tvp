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
        builder = ./owned/build-1.17.3.nix;
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
  ownedDefinition =
    old:
    old
    // {
      constructor = tvp.builder;
      builder = ./owned/build-1.17.3.nix;
      helpers = {
        inherit tvp;
      };
      testContext =
        package:
        tvpLib.tests.fromPackage {
          builder = tvp.builder;
          inherit package;
        };
      source =
        { version, sha256 }:
        pkgs.fetchurl {
          url = "https://rubygems.org/gems/bundler-${version}.gem";
          inherit sha256;
        };
      deps = old.deps // {
        inherit (candidate.tools)
          bash
          coreutils
          gzip
          python
          binutils
          patchelf
          findutils
          ;
      };
    };
  versionTable = builtins.mapAttrs (
    version: entry:
    entry
    // {
      def =
        if !native then
          entry.def
        else if version == "2.5.20" then
          definition
        else
          ownedDefinition entry.def;
    }
  ) retained.versionTable;
  publicArgs = retained // {
    inherit versionTable;
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      if package ? testContext then
        (import ./tests {
          inherit pkgs tvpLib;
          bundler = package;
        })
        // pkgs.lib.optionalAttrs (package.version == "2.5.20") (
          import ./tests/native.nix {
            inherit
              pkgs
              tvp
              tvpLib
              package
              ;
          }
        )
      else
        (retained.extraArgs.mkTests.override { inherit pkgs; }) package
    ) { inherit pkgs; };
  };
  canonical = tvpLib.packages.mkVersions publicArgs;
  pname = "bundler";
in
{
  recipes.${pname} = publicArgs // {
    # Retained Bundler must keep the accepted unsplit Ruby tools and their tests.
    constructionRecipe =
      (import ./legacy.nix {
        inherit pkgs;
        tvp = tvp // {
          packages =
            tvp.packages // (import ../../runtimes/ruby/retained-public.nix { inherit pkgs tvp; }).aliases;
        };
      }).recipes.bundler;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

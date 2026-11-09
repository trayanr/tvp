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
  versionTable = retained.versionTable // {
    "0.2.5" = retained.versionTable."0.2.5" // {
      def = if native then definition else retained.versionTable."0.2.5".def;
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
  pname = "libyaml";
in
{
  recipes.${pname} = publicArgs // {
    constructionRecipe = retained;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  previous = import ./legacy.nix { inherit pkgs tvp; };
  retained = previous.recipes.linux-headers;
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
      "6.9" = {
        constructor = tvp.builder;
        base = candidate.base;
        helpers = {
          inherit tvp;
          inherit (tvpLib) platforms;
        };
        testContext =
          package:
          tvpLib.tests.fromPackage {
            builder = tvp.builder;
            inherit package;
          };
        builder = ./native/build-6.9.nix;
        source =
          { version, sha256 }:
          import <nix/fetchurl.nix> {
            url = "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${version}.tar.xz";
            inherit sha256;
          };
        deps = {
          inherit (constructionTools)
            bash
            coreutils
            xz
            findutils
            sed
            grep
            gawk
            diffutils
            ;
          gnumake = constructionTools.make;
          gnutar = constructionTools.tar;
          perl = tvp.packages.perl_5;
        };

      };
    })."6.9";
  versionTable = retained.versionTable // {
    "6.9" = retained.versionTable."6.9" // {
      def = if native then definition else retained.versionTable."6.9".def;
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
        (import ./legacy.nix { inherit pkgs tvp; }).recipes.linux-headers.extraArgs.mkTests package
    ) { inherit pkgs; };
  };
  canonical = tvpLib.packages.mkVersions publicArgs;
  pname = "linux-headers";
in
{
  recipes.${pname} = publicArgs // {
    constructionRecipe = retained;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

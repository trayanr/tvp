{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  previous = import ./legacy.nix { inherit pkgs tvp; };
  retained = previous.recipes.gn.constructionRecipe;
  candidate = import ../../../bases/source-gnu { };
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  constructionTool =
    name:
    tvpLib.packages.withConstraint {
      category = "construction";
      reason = "Retained source-GNU ${name} is a build-only provider independent of ordinary frontends.";
    } candidate.tools.${name};
  defs = tvpLib.packages.mkDefs {
    "20260707" = {
      constructor = tvp.builder;
      builder = ./native/build-20260707.nix;
      base = candidate.base;
      helpers = {
        inherit tvp;
      };
      source =
        { version, sha256 }:
        import ./native/source.nix {
          inherit (candidate.tools)
            bash
            coreutils
            python
            ;
          curl = tvp.packages.curl;
          caCertificates = tvp.packages.ca-certificates;
          inherit sha256;
          revision = "b8becbd4f7979f63ab3542524b2b4d8db2ce3b52";
        };
      testContext =
        package:
        tvpLib.tests.fromPackage {
          builder = tvp.builder;
          inherit package;
        };
      deps = {
        bash = tvp.packages.bash;
        coreutils = tvp.packages.coreutils;
        ninja = tvp.packages.ninja;
        binutils = tvp.packages.binutils;
        patchelf = tvp.packages.patchelf;
        python = constructionTool "python";
      };
      opts = {
        revision = "b8becbd4f7979f63ab3542524b2b4d8db2ce3b52";
        hardeningDisable = [ "format" ];
        allowWarnings = true;
      };
    };
  };
  versionTable = retained.versionTable // {
    "20260707" = retained.versionTable."20260707" // {
      def = if native then defs."20260707" else retained.versionTable."20260707".def;
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
  pname = "gn";
in
{
  recipes.${pname} = publicArgs // {
    constructionRecipe = retained;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

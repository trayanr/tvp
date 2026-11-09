{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  previous = import ./legacy.nix { inherit pkgs tvp; };
  formerRecipe = previous.recipes.bash;
  constructionRecipe = previous.recipes.bash;
  candidate = import ../../../bases/source-gnu { };
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  constructionTool =
    name:
    tvpLib.packages.withConstraint {
      category = "construction";
      reason = "Retained source-GNU ${name} is an independent build-only construction generation; ordinary self-building tools must not construct themselves or their compiler.";
    } candidate.tools.${name};
  defs = tvpLib.packages.mkDefs {
    "5.2.37" = {
      constructor = tvp.builder;
      builder = ./native/build-5.2.37.nix;
      base = candidate.base;
      helpers = {
        inherit tvp;
      };
      source =
        { version, sha256 }:
        import <nix/fetchurl.nix> {
          url = "https://mirrors.kernel.org/gnu/bash/bash-${version}.tar.gz";
          inherit sha256;
        };
      testContext =
        package:
        tvpLib.tests.fromPackage {
          builder = tvp.builder;
          inherit package;
        };
      opts.cStandard = "gnu17";

      deps = {
        bash = constructionTool "bash";
        coreutils = constructionTool "coreutils";
        gnumake = constructionTool "make";
        gnutar = constructionTool "tar";
        python = constructionTool "python";
        binutils = constructionTool "binutils";
        patchelf = constructionTool "patchelf";
        sed = constructionTool "sed";
        grep = constructionTool "grep";
        gawk = constructionTool "gawk";
        diffutils = constructionTool "diffutils";
        findutils = constructionTool "findutils";
        gzip = constructionTool "gzip";
        ncurses = tvp.packages.ncurses_6;
      };
    };
  };
  versionTable = formerRecipe.versionTable // {
    "5.2.37" = formerRecipe.versionTable."5.2.37" // {
      def = if native then defs."5.2.37" else formerRecipe.versionTable."5.2.37".def;
    };
  };
  publicArgs = formerRecipe // {
    inherit versionTable;
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      if package ? testContext then
        import ./tests/native.nix { inherit pkgs tvpLib package; }
      else
        formerRecipe.extraArgs.mkTests package
    ) { inherit pkgs; };
  };
  canonical = tvpLib.packages.mkVersions publicArgs;
  pname = "bash";
in
{
  recipes.${pname} = publicArgs // {
    inherit constructionRecipe;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

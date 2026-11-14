{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  previous = import ./legacy.nix { inherit pkgs tvp; };
  formerRecipe = builtins.removeAttrs previous.recipes.which [ "constructionRecipe" ];
  constructionRecipe = previous.recipes.which.constructionRecipe;
  candidate = import ../../../bases/source-gnu { };
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  constructionTool =
    name:
    tvpLib.packages.withConstraint {
      category = "construction";
      reason = "Retained source-GNU ${name} is an independent build-only construction generation; ordinary self-building tools must not construct themselves or their compiler.";
    } candidate.tools.${name};
  defs = tvpLib.packages.mkDefs {
    "2.21" = {
      constructor = tvp.builder;
      builder = ./native/build-2.21.nix;
      base = candidate.base;
      helpers = {
        inherit tvp;
      };
      source =
        { version, sha256 }:
        import <nix/fetchurl.nix> {
          url = "https://mirrors.kernel.org/gnu/which/which-${version}.tar.gz";
          inherit sha256;
        };
      testContext =
        package:
        tvpLib.tests.fromPackage {
          builder = tvp.builder;
          inherit package;
        };

      deps = {
        python = constructionTool "python";
        bash = tvp.packages.bash;
        coreutils = tvp.packages.coreutils;
        gnumake = tvp.packages.gnumake;
        gnutar = tvp.packages.gnutar;
        gzip = tvp.packages.gzip;
        gawk = tvp.packages.gawk;
        diffutils = tvp.packages.diffutils;
        findutils = tvp.packages.findutils;
        binutils = tvp.packages.binutils;
        patchelf = tvp.packages.patchelf;
        sed = tvp.packages.gnused;
        grep = tvp.packages.gnugrep;
      };
    };
  };
  versionTable = formerRecipe.versionTable // {
    "2.21" = formerRecipe.versionTable."2.21" // {
      def = if native then defs."2.21" else formerRecipe.versionTable."2.21".def;
    };
  };
  installedArgs = formerRecipe // {
    inherit versionTable;
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      if package ? testContext then
        import ./tests/native.nix { inherit pkgs tvpLib package; }
      else
        formerRecipe.extraArgs.mkTests.override { inherit pkgs; } package
    ) { inherit pkgs; };
  };
  publicArgs = installedArgs // {
    extraArgs = installedArgs.extraArgs // {
      mkTests = pkgs.lib.makeOverridable (
        { pkgs }:
        package:
        (
          if installedArgs.extraArgs.mkTests ? override then
            (installedArgs.extraArgs.mkTests.override { inherit pkgs; }) package
          else
            installedArgs.extraArgs.mkTests package
        )
        // (import ../owned-split-tests.nix { inherit pkgs tvp package; })
      ) { inherit pkgs; };
    };
  };
  canonical = tvpLib.packages.mkVersions publicArgs;
  pname = "which";
in
{
  recipes.${pname} = publicArgs // {
    inherit constructionRecipe;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

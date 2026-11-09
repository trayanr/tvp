{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  retained = import ./legacy.nix { inherit pkgs tvp; };
  constructionRecipe = retained.packageArgs;
  candidate = import ../../../bases/source-gnu { };
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  constructionTool =
    name:
    tvpLib.packages.withConstraint {
      category = "construction";
      reason = "Retained source-GNU ${name} host tool is independent of the ordinary X11 target.";
    } candidate.tools.${name};
  ownedDefs = tvpLib.packages.mkDefs {
    "2026.1" = {
      constructor = tvp.builder;
      builder = ./native/build-2026.1.nix;
      base = candidate.base;
      source =
        { version, sha256 }:
        pkgs.fetchurl {
          url = "https://www.x.org/releases/individual/proto/xorgproto-${version}.tar.xz";
          inherit sha256;
        };
      helpers = {
        inherit tvp;
      };
      testContext =
        package:
        tvpLib.tests.fromPackage {
          builder = tvp.builder;
          inherit package;
        };
      deps = {
        bash = constructionTool "bash";
        coreutils = constructionTool "coreutils";
        gnumake = constructionTool "make";
        gnutar = constructionTool "tar";
        xz = constructionTool "xz";
        findutils = constructionTool "findutils";
        sed = constructionTool "sed";
        grep = constructionTool "grep";
        gawk = constructionTool "gawk";
        diffutils = constructionTool "diffutils";
        python = constructionTool "python";
        binutils = constructionTool "binutils";
        patchelf = constructionTool "patchelf";
        pkgConfig = tvp.packages.pkg-config;
      };
    };
  };
  publicArgs = constructionRecipe // {
    versionTable = constructionRecipe.versionTable // {
      "2026.1" = constructionRecipe.versionTable."2026.1" // {
        def = if native then ownedDefs."2026.1" else constructionRecipe.versionTable."2026.1".def;
      };
    };
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      if package ? testContext then
        import ./tests/native-default.nix { inherit pkgs tvpLib package; }
      else
        (constructionRecipe.extraArgs.mkTests.override { inherit pkgs; }) package
    ) { inherit pkgs; };
  };
  canonical = tvpLib.packages.mkVersions publicArgs;
in
{
  recipes.xorgproto = publicArgs // {
    inherit constructionRecipe;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases {
    pname = "xorgproto";
    versionTable = publicArgs.versionTable;
    inherit canonical;
  };
}

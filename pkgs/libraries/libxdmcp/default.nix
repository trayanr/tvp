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
    "1.1.5" = {
      constructor = tvp.builder;
      builder = ./native/build-1.1.5.nix;
      base = candidate.base;
      source =
        { version, sha256 }:
        pkgs.fetchurl {
          url = "https://www.x.org/releases/individual/lib/libXdmcp-${version}.tar.xz";
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
        xorgproto = tvp.packages.xorgproto;
      };
    };
  };
  publicArgs = constructionRecipe // {
    versionTable = constructionRecipe.versionTable // {
      "1.1.5" = constructionRecipe.versionTable."1.1.5" // {
        def = if native then ownedDefs."1.1.5" else constructionRecipe.versionTable."1.1.5".def;
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
  recipes.libxdmcp = publicArgs // {
    inherit constructionRecipe;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases {
    pname = "libxdmcp";
    versionTable = publicArgs.versionTable;
    inherit canonical;
  };
}

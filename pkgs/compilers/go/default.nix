{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  previous = import ./legacy.nix { inherit pkgs tvp; };
  constructionRecipe = previous.publicArgs;
  candidate = import ../../../bases/source-gnu { };
  constructionTool =
    name:
    tvpLib.packages.withConstraint {
      category = "construction";
      reason = "Retained source-GNU ${name} host tool; independent of the ordinary compiler payload.";
    } candidate.tools.${name};
  defs = tvpLib.packages.mkDefs {
    "1.27.3" = {
      constructor = tvp.builder;
      builder = ./native/build-1.27.3.nix;
      base = candidate.base;
      helpers = {
        inherit tvp;
      };
      source =
        { version, sha256 }:
        pkgs.fetchurl {
          url = "https://dl.google.com/go/go${version}.src.tar.gz";
          inherit sha256;
        };
      testContext =
        package:
        tvpLib.tests.fromPackage {
          builder = tvp.builder;
          inherit package;
        };
      deps = {
        bash = tvp.packages.bash_5;
        coreutils = constructionTool "coreutils";
        helperPython = constructionTool "python";
        gnutar = constructionTool "tar";
        findutils = constructionTool "findutils";
        binutils = constructionTool "binutils";
        patchelf = constructionTool "patchelf";
        gzip = constructionTool "gzip";
        grep = constructionTool "grep";
        sed = constructionTool "sed";
        bootstrap = tvpLib.packages.withConstraint {
          category = "construction";
          reason = "Exact retained source-built Go 1.24.13 seed; no bootstrap chain rebuild in the direct latest procedure.";
        } tvp.canonical.go_1_24_13;
      };
      opts = {
        goOS = "linux";
        goArch = "amd64";
        dynamicLinker = "lib/ld-linux-x86-64.so.2";
      };
    };
  };
  versionTable = constructionRecipe.versionTable // {
    "1.27.3" = constructionRecipe.versionTable."1.27.3" // {
      def =
        if pkgs.stdenv.hostPlatform.system == "x86_64-linux" then
          defs."1.27.3"
        else
          constructionRecipe.versionTable."1.27.3".def;
    };
  };
  publicArgs = constructionRecipe // {
    inherit versionTable;
    extraArgs.mkTests =
      package:
      if package ? testContext then
        import ./tests/native-default.nix { inherit package; }
      else
        constructionRecipe.extraArgs.mkTests package;
  };
  canonical = tvpLib.packages.mkVersions publicArgs;
  pname = "go";
in
{
  recipes.${pname} = publicArgs // {
    inherit constructionRecipe;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

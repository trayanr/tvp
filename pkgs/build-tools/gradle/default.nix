{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  previous = import ./legacy.nix { inherit pkgs tvp; };
  retained = previous.recipes.gradle.constructionRecipe;
  candidate = import ../../../bases/source-gnu { };
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  constructionTool =
    name:
    tvpLib.packages.withConstraint {
      category = "construction";
      reason = "Retained source-GNU ${name} is a build-only provider independent of ordinary frontends.";
    } candidate.tools.${name};
  defs = tvpLib.packages.mkDefs {
    "9.3.1" = {
      constructor = tvp.builder;
      builder = ./native/build-9.3.1.nix;
      base = candidate.base;
      helpers = {
        inherit tvp;
      };
      source =
        { version, sha256 }:
        pkgs.fetchurl {
          url = "https://services.gradle.org/distributions/gradle-${version}-all.zip";
          inherit sha256;
        };
      testContext =
        package:
        tvpLib.tests.fromPackage {
          builder = tvp.builder;
          inherit package;
        };
      deps = {
        jdk = tvp.packages.jdk_21;
        python = tvp.packages.python_3;
        bash = tvp.packages.bash;
        unzip = tvp.packages.unzip;
        coreutils = tvp.packages.coreutils;
        helperPython = constructionTool "python";
      };
      blob = {
        reason = "Pinned upstream Gradle distribution with its bundled Java bytecode and native service libraries.";
        needs = "Source Gradle bootstrap and a locked source dependency repository.";
        blocked.package = "gradle-from-source";
      };
    };
  };
  versionTable = retained.versionTable // {
    "9.3.1" = retained.versionTable."9.3.1" // {
      def = if native then defs."9.3.1" else retained.versionTable."9.3.1".def;
    };
  };
  publicArgs = retained // {
    inherit versionTable;
    testDeps = {
      grep = tvp.packages.gnugrep;
      sed = tvp.packages.gnused;
      findutils = tvp.packages.findutils;
    };
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
  pname = "gradle";
in
{
  recipes.${pname} = publicArgs // {
    constructionRecipe = retained;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

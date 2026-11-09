{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  previous = import ./legacy.nix { inherit pkgs tvp; };
  retained = previous.recipes.php;
  candidate = import ../../../bases/source-gnu { };
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  constructionTool =
    name:
    tvpLib.packages.withConstraint {
      category = "construction";
      kind = "exact";
      namespace = "source-gnu.tools";
      selector = name;
      reason = "Retained source-GNU ${name} host tool, independent of the ordinary target.";
    } candidate.tools.${name};
  ownedDefs = tvpLib.packages.mkDefs {
    "8.5.12" = {
      constructor = tvp.builder;
      builder = ./native/build-8.5.12.nix;
      base = candidate.base;
      helpers = {
        inherit tvp;
      };
      source =
        { version, sha256 }:
        import <nix/fetchurl.nix> {
          url = "https://www.php.net/distributions/php-${version}.tar.gz";
          inherit sha256;
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
        toolPython = constructionTool "python";
        gnumake = constructionTool "make";
        gnutar = constructionTool "tar";
        findutils = constructionTool "findutils";
        sed = constructionTool "sed";
        grep = constructionTool "grep";
        gawk = constructionTool "gawk";
        diffutils = constructionTool "diffutils";
        binutils = constructionTool "binutils";
        patchelf = constructionTool "patchelf";
        gzip = constructionTool "gzip";
        pkgConfig = tvp.packages.pkg-config;
        openssl = tvp.packages.openssl;
        zlib = tvp.packages.zlib_1;
        libxml2 = tvp.packages.libxml2_2;
        readline = tvp.packages.readline_8;
        ncurses = tvp.packages.ncurses_6;
        sqlite = tvp.packages.sqlite_3;
      };

    };
  };
  versionTable = retained.versionTable // {
    "8.5.12" = retained.versionTable."8.5.12" // {
      def = if native then ownedDefs."8.5.12" else retained.versionTable."8.5.12".def;
    };
  };
  publicArgs = retained // {
    inherit versionTable;
    testDeps = retained.testDeps // {
      autoconf = tvp.packages.autoconf_2;
    };
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      if package ? testContext then
        import ./tests/native.nix { inherit pkgs tvpLib package; }
      else
        (retained.extraArgs.mkTests.override { inherit pkgs; }) package
    ) { inherit pkgs; };
  };
  canonical = tvpLib.packages.mkVersions publicArgs;
  pname = "php";
in
{
  recipes.${pname} = publicArgs // {
    constructionRecipe = retained;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

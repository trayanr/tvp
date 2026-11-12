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
  # Retain each historical dependency profile and option set. Only construction
  # and test-only dependencies are separated; no dependency upgrades are implied.
  ordinary =
    def:
    def
    // {
      constructor = tvp.builder;
      builder = ./ordinary + "/${builtins.baseNameOf def.builder}";
      base = candidate.base;
      helpers = {
        inherit tvp;
      };
      source =
        { version, sha256 }:
        import <nix/fetchurl.nix> {
          url =
            if
              builtins.elem (builtins.baseNameOf def.builder) [
                "build-5.0.5.nix"
                "build-5.1.6.nix"
                "build-5.2.17.nix"
              ]
            then
              "https://museum.php.net/php5/php-${version}.tar.gz"
            else
              "https://www.php.net/distributions/php-${version}.tar.gz";
          inherit sha256;
        };
      testContext =
        package:
        tvpLib.tests.fromPackage {
          builder = tvp.builder;
          inherit package;
        };
      deps = builtins.removeAttrs def.deps [ "testAutoconf" ] // {
        inherit (ownedDefs."8.5.12".deps)
          bash
          coreutils
          toolPython
          gnumake
          gnutar
          findutils
          sed
          grep
          gawk
          diffutils
          binutils
          patchelf
          gzip
          ;
      };
    };
  versionTable = builtins.mapAttrs (
    version: entry:
    entry
    // {
      def =
        if !native then
          entry.def
        else if version == "8.5.12" then
          ownedDefs."8.5.12"
        else
          ordinary entry.def;
    }
  ) retained.versionTable;
  publicArgs = retained // {
    inherit versionTable;
    testDeps = retained.testDeps // {
      autoconf = tvp.packages.autoconf_2;
    };
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      if package ? testContext then
        if package.tvp.builder == "build-8.5.12.nix" then
          import ./tests/native.nix { inherit pkgs tvpLib package; }
        else
          import ./tests {
            inherit pkgs tvpLib;
            php = package;
          }
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

{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  testLib = pkgs.lib;
  previous = import ./legacy.nix { inherit pkgs tvp; };
  formerRecipe = previous.publicArgs;
  candidate = import ../../../bases/source-gnu { };
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  constructionTool =
    name:
    tvpLib.packages.withConstraint {
      category = "construction";
      reason = "Retained source-GNU ${name} is an independent build-only host generation; ordinary Python/Binutils are downstream of this library wave.";
    } candidate.tools.${name};
  defs = tvpLib.packages.mkDefs {
    "2.15.4" = {
      constructor = tvp.builder;
      builder = ./native/build-2.15.4.nix;
      base = candidate.base;
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
        inherit (tvp.packages)
          bash
          coreutils
          gnumake
          gnutar
          gnused
          gnugrep
          gawk
          diffutils
          findutils
          ;
        xz = tvp.packages.xz_5;
        zlib = tvp.packages.zlib_1;
        pkg-config = tvp.packages.pkg-config;
        python = constructionTool "python";
        binutils = constructionTool "binutils";
        patchelf = constructionTool "patchelf";
      };
    };
  };
  versionTable = formerRecipe.versionTable // {
    "2.15.4" = formerRecipe.versionTable."2.15.4" // {
      def = if native then defs."2.15.4" else formerRecipe.versionTable."2.15.4".def;
    };
  };
  publicArgs = formerRecipe // {
    inherit versionTable;
    source =
      { version, sha256 }:
      pkgs.fetchurl {
        url = "https://download.gnome.org/sources/libxml2/${testLib.versions.majorMinor version}/libxml2-${version}.tar.xz";
        inherit sha256;
      };
    extraArgs.mkTests = testLib.makeOverridable (
      { pkgs }:
      libxml2:
      import ./tests {
        inherit tvpLib libxml2;
        pkgs = if libxml2 ? testContext then { lib = testLib; } else pkgs;
        inherit (libxml2.tvp.declaredTestDependencies) pkg-config gzip xz;
      }
    ) { inherit pkgs; };
  };
  canonical = tvpLib.packages.mkVersions publicArgs;
  pname = "libxml2";
in
{
  recipes.${pname} = publicArgs // {
    constructionRecipe = formerRecipe;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

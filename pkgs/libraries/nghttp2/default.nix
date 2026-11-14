{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  testLib = pkgs.lib;
  previous = import ./legacy.nix { inherit pkgs tvp; };
  formerRecipe = previous.recipes.nghttp2;
  constructionRecipe = formerRecipe;
  candidate = import ../../../bases/source-gnu { };
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  constructionTool =
    name:
    tvpLib.packages.withConstraint {
      category = "construction";
      reason = "Retained source-GNU ${name} is an independent build-only host generation; ordinary Python/Binutils consume Zstd and cannot construct it.";
    } candidate.tools.${name};
  defs = tvpLib.packages.mkDefs {
    "1.70.0" = {
      constructor = tvp.builder;
      builder = ./native/build-1.70.0.nix;
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
          xz
          ;
        sed = tvp.packages.gnused;
        grep = tvp.packages.gnugrep;
        gawk = tvp.packages.gawk;
        diffutils = tvp.packages.diffutils;
        findutils = tvp.packages.findutils;
        pkg-config = tvp.packages.pkg-config;
        python = constructionTool "python";
        binutils = constructionTool "binutils";
        patchelf = constructionTool "patchelf";
      };
    };
  };
  versionTable = formerRecipe.versionTable // {
    "1.70.0" = formerRecipe.versionTable."1.70.0" // {
      def = if native then defs."1.70.0" else formerRecipe.versionTable."1.70.0".def;
    };
  };
  publicArgs = formerRecipe // {
    inherit versionTable;
    source =
      { version, sha256 }:
      pkgs.fetchurl {
        url = "https://github.com/nghttp2/nghttp2/releases/download/v${version}/nghttp2-${version}.tar.xz";
        inherit sha256;
      };
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      let
        testPkgs =
          if package ? testContext then
            { lib = testLib; }
          else
            tvpLib.tests.withBase {
              inherit pkgs;
              base.stdenv = package.stdenv;
            };
      in
      import ./tests {
        inherit tvpLib package;
        pkgs = testPkgs;
      }
    ) { inherit pkgs; };
  };
  canonical = tvpLib.packages.mkVersions publicArgs;
  pname = "nghttp2";
in
{
  recipes.${pname} = publicArgs // {
    inherit constructionRecipe;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

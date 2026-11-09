{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  previous = import ./legacy.nix { inherit pkgs tvp; };
  formerRecipe = previous.recipes.binutils;
  constructionRecipe = previous.recipes.binutils;
  candidate = import ../../../bases/source-gnu { };
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  constructionTool =
    name:
    tvpLib.packages.withConstraint {
      category = "construction";
      reason = "Retained source-GNU ${name} is an independent build-only construction generation; ordinary self-building tools must not construct themselves or their compiler.";
    } candidate.tools.${name};
  defs = tvpLib.packages.mkDefs {
    "2.42" = {
      constructor = tvp.builder;
      builder = ./native/build-2.42.nix;
      base = candidate.base;
      helpers = {
        inherit tvp;
      };
      source =
        { version, sha256 }:
        import <nix/fetchurl.nix> {
          url = "https://mirrors.kernel.org/gnu/binutils/binutils-${version}.tar.xz";
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
        python = constructionTool "python";
        binutils = constructionTool "binutils";
        patchelf = constructionTool "patchelf";
        bash = tvp.packages.bash;
        coreutils = tvp.packages.coreutils;
        gnumake = tvp.packages.gnumake;
        gnutar = tvp.packages.gnutar;
        gzip = tvp.packages.gzip;
        xz = tvp.packages.xz;
        gawk = tvp.packages.gawk;
        diffutils = tvp.packages.diffutils;
        findutils = tvp.packages.findutils;
        zlib = tvp.packages.zlib;
        zstd = tvp.packages.zstd;
        perl = tvp.packages.perl;
        pkg-config = tvp.packages.pkg-config;
        bison = tvp.packages.bison;
        texinfo = tvp.packages.texinfo;
        sed = tvp.packages.gnused;
        grep = tvp.packages.gnugrep;
      };
    };
  };
  versionTable = formerRecipe.versionTable // {
    "2.42" = formerRecipe.versionTable."2.42" // {
      def = if native then defs."2.42" else formerRecipe.versionTable."2.42".def;
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
        formerRecipe.extraArgs.mkTests.override { inherit pkgs; } package
    ) { inherit pkgs; };
  };
  canonical = tvpLib.packages.mkVersions publicArgs;
  pname = "binutils";
in
{
  recipes.${pname} = publicArgs // {
    inherit constructionRecipe;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  previous = import ./legacy.nix { inherit pkgs tvp; };
  formerRecipe = builtins.removeAttrs previous.recipes.patch [ "constructionRecipe" ];
  constructionRecipe = previous.recipes.patch.constructionRecipe;
  candidate = import ../../../bases/source-gnu { };
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  constructionTool =
    name:
    tvpLib.packages.withConstraint {
      category = "construction";
      reason = "Retained source-GNU ${name} is an independent build-only construction generation; ordinary self-building tools must not construct themselves or their compiler.";
    } candidate.tools.${name};
  defs = tvpLib.packages.mkDefs {
    "2.8.1" = {
      constructor = tvp.builder;
      builder = ./native/build-2.8.1.nix;
      base = candidate.base;
      helpers = {
        inherit tvp;
      };
      source =
        { version, sha256 }:
        import <nix/fetchurl.nix> {
          url = "https://mirrors.kernel.org/gnu/patch/patch-${version}.tar.xz";
          inherit sha256;
        };
      testContext =
        package:
        tvpLib.tests.fromPackage {
          builder = tvp.builder;
          inherit package;
        };

      patches = [
        {
          file = ./patches/bad-filenames-input.patch;
          reason = "Precompute invalid-filename input without changing rejection assertions or hiding the EPIPE race.";
        }
      ];
      deps = {
        python = constructionTool "python";
        patch = constructionTool "patch";
        bash = tvp.packages.bash;
        coreutils = tvp.packages.coreutils;
        gnumake = tvp.packages.gnumake;
        gnutar = tvp.packages.gnutar;
        gzip = tvp.packages.gzip;
        xz = tvp.packages.xz;
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
    "2.8.1" = formerRecipe.versionTable."2.8.1" // {
      def = if native then defs."2.8.1" else formerRecipe.versionTable."2.8.1".def;
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
        formerRecipe.extraArgs.mkTests package
    ) { inherit pkgs; };
  };
  canonical = tvpLib.packages.mkVersions publicArgs;
  pname = "patch";
in
{
  recipes.${pname} = publicArgs // {
    inherit constructionRecipe;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

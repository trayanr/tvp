{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  base = tvp.bases.default;
  seed =
    reason:
    tvpLib.packages.withConstraint {
      category = "construction";
      inherit reason;
    };
  floorTool =
    name:
    seed
      "Completed default-base ${name} is a build-only seed for the foundational tool wave; it avoids following the canonical tool graph while rebuilding its prerequisites."
      base.components.floor.${name};
  defs = tvpLib.packages.mkDefs {
    "4.3" = {
      builder = ./build-4.3.nix;
      base = tvp.bases.default;
      deps = { };
    };
    "4.4.1" = {
      constructor = tvp.builder;
      builder = ./owned/build-4.4.1.nix;
      inherit base;
      helpers = {
        inherit tvp;
      };
      deps = {
        bash = tvp.packages.bash_5;
        coreutils = floorTool "coreutils";
        gnumake = floorTool "gnumake";
        gnutar = floorTool "gnutar";
        gzip = floorTool "gzip";
        python = seed "Completed libc-build helper interpreter is build-only; using its existing recipe output avoids a new Python prerequisite cycle." base.components.libc.tvp.deps.python3Minimal;
        binutils = seed "Completed base Binutils supplies build-only output inspection and stripping without following its canonical prerequisite graph." base.components.binutils;
        patchelf = seed "Completed base Patchelf supplies build-only ELF finalization before the canonical Patchelf advance." base.fixupTools.patchelf;
        perl = seed "Completed base Perl executes the upstream Make test harness as a build-only input." base.components.perl;
      };
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."4.3";
      releases."4.3" = "sha256-4F/d5HxffKRctpfpc4lP9PXXnhO3UO1X17Ztje/Hjhk=";
      releases."4.4" = "sha256-WB9NToctp0s5Qch0IViYp9NYAvA3Mr3M7h1KeXkQXRg=";
    }
    {
      def = defs."4.4.1";
      releases."4.4.1" = "sha256-3Rb7HWe/q3mnL16DkHNcSePo5wtJRaFasfgd23hlj7M=";
    }
  ];
  pname = "gnumake";
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests =
      package:
      import ./tests {
        inherit tvpLib package;
        pkgs = tvpLib.tests.withBase {
          inherit pkgs;
          base.stdenv = package.stdenv;
        };
      };
    packageMeta = {
      upstream = {
        type = "directory-index";
        url = "https://mirrors.kernel.org/gnu/make/";
        pattern = "make-[0-9][^\"]*\\.tar\\.gz";

        normalise =
          file:
          if pkgs.lib.hasPrefix "make-" file && pkgs.lib.hasSuffix ".tar.gz" file then
            pkgs.lib.removeSuffix ".tar.gz" (pkgs.lib.removePrefix "make-" file)
          else
            null;

        include = version: builtins.match "[0-9].*" version != null;
      };
    };
  };
  constructionRecipe = packageArgs // {
    versionTable = versionTable // {
      "4.4.1" = versionTable."4.4.1" // {
        def = defs."4.3";
      };
    };
  };
  publicArgs = packageArgs // {
    source =
      { version, sha256 }:
      pkgs.fetchurl {
        url = "https://mirrors.kernel.org/gnu/make/make-${version}.tar.gz";
        inherit sha256;
      };
    extraArgs.mkTests =
      package:
      packageArgs.extraArgs.mkTests package
      // pkgs.lib.optionalAttrs (package.version == "4.4.1") (
        import ./tests/owned.nix {
          inherit tvp tvpLib package;
          pkgs = tvpLib.tests.withBase {
            inherit pkgs;
            base.stdenv = package.stdenv;
          };
        }
      );
  };
  canonical = tvpLib.packages.mkVersions publicArgs;

in
{
  recipes.${pname} = publicArgs // {
    inherit constructionRecipe;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

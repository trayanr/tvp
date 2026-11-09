{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  testLib = pkgs.lib;
  previous = import ./legacy.nix { inherit pkgs tvp; };
  formerRecipe = previous.publicArgs;
  candidate = import ../../../bases/source-gnu { };
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  defs = tvpLib.packages.mkDefs {
    "6.0" = {
      constructor = tvp.builder;
      builder = ./native/build-6.0.nix;
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
      # Original Unix probes require these historic C assumptions. These are
      # explicit compiler arguments; no inherited setup hook supplies them.
      opts.cflags = "-fcommon -std=gnu17 -Wno-error=implicit-int -Wno-error=implicit-function-declaration";
      opts.hardeningDisable = [ "format" ];
      deps = {
        inherit (tvp.packages)
          bash
          coreutils
          gnumake
          gnutar
          gzip
          gnused
          gnugrep
          gawk
          diffutils
          findutils
          ;
        python = tvp.packages.python_3;
        patchelf = tvp.packages.patchelf;
        binutils = tvpLib.packages.withConstraint {
          category = "construction";
          reason = "Retained source-GNU Binutils is an independently constructed ELF inspector until ordinary Binutils is ported to the source base.";
        } candidate.tools.binutils;
      };
    };
  };
  versionTable = formerRecipe.versionTable // {
    "6.0" = formerRecipe.versionTable."6.0" // {
      def = if native then defs."6.0" else formerRecipe.versionTable."6.0".def;
    };
  };
  publicArgs = formerRecipe // {
    inherit versionTable;
    source =
      { version, sha256 }:
      pkgs.fetchurl {
        url = "https://downloads.sourceforge.net/infozip/unzip60.tar.gz";
        inherit sha256;
      };
    testDeps.zip = tvp.packages.zip;
    extraArgs.mkTests =
      testLib.makeOverridable
        (
          { pkgs, zip }:
          package:
          (if package ? testContext then import ./tests else import ./tests/legacy.nix) {
            inherit tvpLib package zip;
            pkgs =
              if package ? testContext then
                { lib = testLib; }
              else
                tvpLib.tests.withBase {
                  inherit pkgs;
                  base.stdenv = package.stdenv;
                };
          }
        )
        {
          inherit pkgs;
          zip = tvp.packages.zip;
        };
  };
  canonical = tvpLib.packages.mkVersions publicArgs;
  pname = "unzip";
in
{
  recipes.unzip = publicArgs;
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

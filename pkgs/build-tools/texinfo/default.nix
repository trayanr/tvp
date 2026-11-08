{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  previous = import ./legacy.nix { inherit pkgs tvp; };
  constructionRecipe = previous.recipes.texinfo.constructionRecipe;
  candidate = import ../../../bases/source-gnu { };
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  host =
    name: reason:
    tvpLib.packages.withConstraint {
      category = "construction";
      inherit reason;
    } candidate.tools.${name};
  defs = tvpLib.packages.mkDefs {
    "7.1" = {
      constructor = tvp.builder;
      builder = ./native/build-7.1.nix;
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
        bash = tvp.packages.bash_5;
        coreutils = tvp.packages.coreutils_9;
        gnumake = tvp.packages.gnumake_4;
        gnutar = tvp.packages.gnutar_1;
        xz = tvp.packages.xz_5;
        findutils = tvp.packages.findutils_4;
        sed = tvp.packages.gnused_4;
        grep = tvp.packages.gnugrep_3;
        gawk = tvp.packages.gawk_5;
        diffutils = tvp.packages.diffutils_3;
        python = host "python" "Independent source/output helper avoids catalogue dependency cycles.";
        binutils = host "linker" "Owned ELF output tools independent of catalogue consumers.";
        patchelf = host "patchelf" "Owned RPATH tool independent of catalogue consumers.";
        perl = tvp.packages.perl_5;
        ncurses = tvp.packages.ncurses_6;
        localeTools = host "localeTools" "Locale executable must match the selected source-owned libc; ordinary default libc is a different generation.";
        patch = host "patch" "Source-native source-preparation tool; keep the recipe independent of legacy-base Patch construction. Ordinary Patch remains covered by latest validation.";
        gzip = tvp.packages.gzip_1;
      };
      opts.cStandard = "gnu17";
      patches = [
        {
          file = ./patches/wide-ncurses.patch;
          reason = "Library integration: include ncursesw in Texinfo's terminal-library probes so its Info reader is built with TVP's wide-character ncurses.";
        }
        {
          file = ./patches/locale-program.patch;
          reason = "Store-layout adaptation: bind the locale program invoked by Texinfo's translation support to its declared glibc tools instead of relying on the caller's PATH.";
        }
        {
          file = ./patches/perl-5.44-precedence.patch;
          reason = "Perl 5.44 rejects ambiguous negation; compare the output filename directly without suppressing warnings.";
        }
      ];
    };
  };
  versionTable = previous.recipes.texinfo.versionTable // {
    "7.1" = previous.recipes.texinfo.versionTable."7.1" // {
      def = if native then defs."7.1" else previous.recipes.texinfo.versionTable."7.1".def;
    };
  };
  publicArgs =
    {
      inherit (previous.recipes.texinfo) infra pname;
    }
    // {
      inherit versionTable;
      source =
        { version, sha256 }:
        pkgs.fetchurl {
          url = "https://mirrors.kernel.org/gnu/texinfo/texinfo-${version}.tar.xz";
          inherit sha256;
        };
      testDeps = {
        sentinel = (import ../../../bases/source-gnu/tests/probes.nix { }).sentinel;
        alternateSource = (import ../../../bootstrap/source-cmake-prerequisite-tests.nix { }).alternate;
        sourceGzip = candidate.tools.gzip;
      };
      extraArgs.mkTests = pkgs.lib.makeOverridable (
        { pkgs }:
        package:
        if package ? testContext then
          import ./tests/native-default.nix {
            inherit
              pkgs
              tvp
              tvpLib
              package
              ;
          }
        else
          (previous.recipes.texinfo.extraArgs.mkTests.override { inherit pkgs; }) package
      ) { inherit pkgs; };
    };
  canonical = tvpLib.packages.mkVersions publicArgs;
  pname = "texinfo";
in
{
  recipes.${pname} = publicArgs // {
    inherit constructionRecipe;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

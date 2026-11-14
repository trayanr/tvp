{ pkgs, tvp }:
let
  previous = import ./retained-index.nix { inherit pkgs tvp; };
  prior = previous.recipes."texinfo";
  retained = prior.constructionRecipe or prior;
  earlier = import ../../../bases/source-gnu { };
  full = tvp.baseTiers.full;
  profileBase = full.override {
    shell = tvp.packages.bash_5;
    coreutils = tvp.packages.coreutils_9;
    standardTools = {
      python = earlier.tools.python;
      patchelf = earlier.tools.patchelf;
      patch = earlier.tools.patch;
      gnumake = tvp.packages.gnumake_4;
      gnutar = tvp.packages.gnutar_1;
      xz = tvp.packages.xz_5;
      gzip = tvp.packages.gzip_1;
      findutils = tvp.packages.findutils_4;
      sed = tvp.packages.gnused_4;
      grep = tvp.packages.gnugrep_3;
      gawk = tvp.packages.gawk_5;
      diffutils = tvp.packages.diffutils_3;
    };
  };
  pname = "texinfo";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-7.1-current.nix;
        base = profileBase;
        deps = {
          binutils = earlier.tools.linker;
          perl = tvp.packages.perl_5;
          ncurses = tvp.packages.ncurses_6;
          localeTools = earlier.tools.localeTools;
        };
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
        opts.cStandard = "gnu17";
      };
      releases = {
        "7.1" = "sha256-3u7J8Z8VngRv34rSIjGYGAbawzLMNy8cdjUErYKzCVM=";
      };
    }
  ];
  testDeps = (prior.testDeps or { }) // {
    sentinel = (import ../../../bases/source-gnu/tests/probes.nix { }).sentinel;
    alternateSource = (import ../../../bootstrap/source-cmake-prerequisite-tests.nix { }).alternate;
    sourceGzip = earlier.tools.gzip;
  };
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable testDeps;
    packageMeta = prior.packageMeta or { };
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://mirrors.kernel.org/gnu/texinfo/texinfo-${version}.tar.xz";
        inherit sha256;
      };
    tests = import ./tests;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes."texinfo" = family // {
    constructionRecipe = retained;
  };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

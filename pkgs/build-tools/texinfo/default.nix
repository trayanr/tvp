{ tvp, ... }:
let
  earlier = import ../../../bases/source-gnu { };
  pname = "texinfo";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-7.1-current.nix;
        deps = {

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
  testDeps = {
    sentinel = tvp.lib.tests.fixtures.sentinel;
    alternateSource = tvp.lib.tests.fixtures.alternateSource;
    sourceGzip = earlier.tools.gzip;
  };
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable testDeps;
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
  recipes."texinfo" = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

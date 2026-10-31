{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "7.1" = {
      builder = ./build-7.1.nix;
      base = tvp.bases.default;
      # system.h's legacy strerror() declaration conflicts under C23.
      opts.cStandard = "gnu17";
      deps = {
        perl = tvp.packages.perl_5;
        ncurses = tvp.packages.ncurses_6;
        localeTools = tvp.bases.default.stdenv.cc.libc.bin;
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
      ];
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."7.1";
      releases."7.1" = "sha256-3u7J8Z8VngRv34rSIjGYGAbawzLMNy8cdjUErYKzCVM=";
    }
  ];
  pname = "texinfo";
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      import ./tests {
        inherit tvpLib package;
        pkgs = tvpLib.tests.withBase {
          inherit pkgs;
          base.stdenv = package.stdenv;
        };
      }
    ) { inherit pkgs; };
  };
  canonical = tvpLib.packages.mkVersions packageArgs;

in
{
  recipes.${pname} = packageArgs;
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

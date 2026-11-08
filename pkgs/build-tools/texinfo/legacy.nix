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
  # Preserve the complete old factory for frozen construction graphs. Ordinary
  # XS uses the compiler published by the selected owned Perl's Config.
  constructionRecipe = packageArgs;
  compatDefs = tvpLib.packages.mkDefs {
    "7.1" = {
      builder = ./compat/build-7.1.nix;
      base = tvp.bases.default;
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
  publicArgs = packageArgs // {
    versionTable = versionTable // {
      "7.1" = versionTable."7.1" // {
        def = if tvp.packages.perl_5 ? testContext then compatDefs."7.1" else defs."7.1";
      };
    };
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

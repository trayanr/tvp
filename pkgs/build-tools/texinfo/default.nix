{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "7.1" = {
      builder = ./build-7.1.nix;
      base = tvp.bases.default;
      deps = {
        perl = tvp.packages.perl_5_44_0;
        ncurses = tvp.packages.ncurses_6_6;
        localeTools = tvp.packages.glibc_2_39.bin;
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
      { pkgs }: package: import ./tests { inherit pkgs tvpLib package; }
    ) { inherit pkgs; };
  };
  canonical = tvpLib.packages.mkVersions packageArgs;
  variants = tvpLib.packages.mkVariants (
    packageArgs
    // {
      inherit pkgs;
      profiles = {
        gcc13-owned = {
          base = tvp.bases.gcc13-owned;
          versions."7.1" = {
            deps = {
              perl = tvp.bases.gcc13-owned.components.perl;
              ncurses = tvp.bases.gcc13-owned.components.libraries.ncurses;
              localeTools = tvp.bases.gcc13-owned.components.libc.bin;
            };
          };
        };
      };
    }
  );

in
{
  inherit canonical variants;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

{ tvp, ... }:
let
  pname = "patch";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-2.7.6-native.nix;

      };
      releases = {
        "2.7.6" = "sha256-rGEL2per4Nn2t8ljJVoR3LGWwl4zfGH5Tkd41jLx2P0=";
      };
    }
    {
      def = {
        builder = ./build-2.8-native.nix;

      };
      releases = {
        "2.8" = "sha256-+Hzuae7CtPy/YKOWsDCtaqNBXxkqpffuhMrV4R9/WuM=";
      };
    }
    {
      def = {
        builder = ./build-2.8.1-native.nix;

        patches = [
          {
            file = ./patches/bad-filenames-input.patch;
            reason = "Precompute invalid-filename input without changing rejection assertions or hiding the EPIPE race.";
          }
        ];
      };
      releases = {
        "2.8.1" = "sha256-MkDHlZxTR8jtNH48QgHAM3v0JA1c8J1oiJ5Y7qujDhc=";
      };
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;

    source = tvp.lib.sources.directory {
      url = "https://mirrors.kernel.org/gnu/patch/";
      archive = "patch-{version}.tar.xz";
      discovery = {

        # Older releases use gzip; discover each stable version across formats.
        # The adapter deduplicates archive/signature matches after normalisation.
        pattern = "patch-[0-9]+(\\.[0-9]+)*\\.tar\\.(gz|bz2|xz|lz|zst|Z)";
        normalise =
          file:
          let
            match = builtins.match "patch-([0-9]+(\\.[0-9]+)*)\\.tar\\.(gz|bz2|xz|lz|zst|Z)" file;
          in
          if match == null then null else builtins.head match;
      };
    };
    tests = import ./tests;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes."patch" = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

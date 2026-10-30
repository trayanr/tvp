{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "2.7.6" = {
      builder = ./build-2.7.6.nix;
      base = tvp.bases.default;
      deps = {

      };
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."2.7.6";
      releases = {
        "2.7.6" = "sha256-rGEL2per4Nn2t8ljJVoR3LGWwl4zfGH5Tkd41jLx2P0=";
        "2.8" = "sha256-+Hzuae7CtPy/YKOWsDCtaqNBXxkqpffuhMrV4R9/WuM=";
        "2.8.1" = "sha256-MkDHlZxTR8jtNH48QgHAM3v0JA1c8J1oiJ5Y7qujDhc=";
      };
    }
  ];
  pname = "patch";
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests = package: import ./tests { inherit pkgs tvpLib package; };
    packageMeta.upstream = {
      type = "directory-index";
      url = "https://mirrors.kernel.org/gnu/patch/";
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
  canonical = tvpLib.packages.mkVersions packageArgs;

in
{
  recipes.${pname} = packageArgs;
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

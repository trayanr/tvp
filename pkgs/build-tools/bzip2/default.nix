{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "1.0.6" = {
      builder = ./build-1.0.6.nix;
      base = tvp.bases.default;
      deps = { };
    };
    "1.0.8" = {
      builder = ./build-1.0.8.nix;
      base = tvp.bases.default;
      deps = {

      };
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."1.0.6";
      releases = {
        "1.0.6" = "sha256-ooSPNPzV1s9H3vAEYfy1KKBITY7e+CCNbS4pCdxh2c0=";
        "1.0.7" = "sha256-52iofFsaeVEUmb60FQC8xMryA3Jv/0am9fmtJ/4Iqys=";
      };
    }
    {
      def = defs."1.0.8";
      releases."1.0.8" = "sha256-q1oDF27hBtPw+pDjgdpHjdrkBZGBU8yiSOaCzQxKImk=";
    }
  ];
  pname = "bzip2";
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests = package: import ./tests { inherit pkgs tvpLib package; };
    packageMeta.upstream = {
      type = "directory-index";
      url = "https://sourceware.org/pub/bzip2/";
      pattern = "bzip2-[0-9]+(\\.[0-9]+)+\\.tar\\.(gz|bz2|xz|lz)";
      normalise =
        file:
        let
          match = builtins.match "bzip2-([0-9]+(\\.[0-9]+)+)\\.tar\\.(gz|bz2|xz|lz)" file;
        in
        if match == null then null else builtins.head match;
      include = version: builtins.match "[0-9]+(\\.[0-9]+)+" version != null;
    };
  };
  canonical = tvpLib.packages.mkVersions packageArgs;

in
{
  recipes.${pname} = packageArgs;
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

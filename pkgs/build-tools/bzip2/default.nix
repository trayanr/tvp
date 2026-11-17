{ tvp, ... }:
let
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        opts.helperInterface = "declared-tools";
      };
      releases = {
        "1.0.6" = "sha256-ooSPNPzV1s9H3vAEYfy1KKBITY7e+CCNbS4pCdxh2c0=";
        "1.0.7" = "sha256-52iofFsaeVEUmb60FQC8xMryA3Jv/0am9fmtJ/4Iqys=";
      };
    }
    {
      def = {
        builder = ./build.nix;
      };
      releases."1.0.8" = "sha256-q1oDF27hBtPw+pDjgdpHjdrkBZGBU8yiSOaCzQxKImk=";
    }
  ];

  pname = "bzip2";
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.directory {
      url = "https://sourceware.org/pub/bzip2/";
      archive = "bzip2-{version}.tar.gz";
      discovery = {

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
    tests = import ./tests/installed.nix;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.bzip2 = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

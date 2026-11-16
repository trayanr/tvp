{ tvp, ... }:
let
  testBase = tvp.bases.gcc_16.full;
  locale =
    (tvp.lib.tests.fixtures.forBase {
      builder = tvp.builder;
      base = testBase;
    }).gnuLocale;
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-4.10.0.nix;
        deps = {
          coreutils = tvp.packages.coreutils;
        };
      };
      releases = {
        "4.10.0" = "sha256-E4fgtn/yR9Kr3pmPkN+/cMFJE5Glnd/suK5ph4nwpPU=";
      };
    }
    {
      def = {
        builder = ./build-4.11.0.nix;
        deps = {
          coreutils = tvp.packages.coreutils;
        };
      };
      releases = {
        "4.11.0" = "sha256-v9GcsGzHHzNS1WfpAoTYzawCrIl3S76t8LUzsMEUMv0=";
      };
    }
  ];
  pname = "findutils";
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    packageMeta.upstream = {
      type = "directory-index";
      url = "https://mirrors.kernel.org/gnu/findutils/";
      pattern = "findutils-[0-9][^\"]*\\.tar\\.(gz|bz2|xz|lz)";
      # Multiple archive formats describe the same numeric release. The
      # directory-index adapter deduplicates the normalised versions.
      normalise =
        file:
        let
          matched = builtins.match "findutils-([0-9]+(\\.[0-9]+)+)\\.tar\\.(gz|bz2|xz|lz)" file;
        in
        if matched == null then null else builtins.head matched;
      include = version: builtins.match "[0-9]+(\\.[0-9]+)+" version != null;
    };
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://mirrors.kernel.org/gnu/findutils/findutils-${version}.tar.xz";
        inherit sha256;
      };
    tests = import ./tests;
    testDeps = {
      inherit locale;
    };
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.findutils = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

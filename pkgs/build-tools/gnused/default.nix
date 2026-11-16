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
        builder = ./build-4.9.nix;
        deps = {
          acl = tvp.packages.acl_2;
        };
      };
      releases = {
        "4.9" = "sha256-biJrcy4c1zlGStaGK9Ghq6QteYKSLaelNRljHSSXUYE=";
      };
    }
    {
      def = {
        builder = ./build-4.10.nix;
        deps = {
          acl = tvp.packages.acl_2;
        };
      };
      releases = {
        "4.10" = "sha256-uOchgrLslqNXTimYxHt6qmTMIM4ADY6awxPMB87PKMc=";
      };
    }
  ];
  pname = "gnused";
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    packageMeta.upstream = {
      type = "directory-index";
      url = "https://mirrors.kernel.org/gnu/sed/";
      # Capture whole filenames so signatures and archival README placeholders
      # cannot be mistaken for available tarballs by a partial regex match.
      pattern = "sed-[0-9][^\"<>[:space:]]*";
      normalise =
        file:
        let
          matched = builtins.match "sed-([0-9]+(\\.[0-9]+)*)\\.tar\\.(gz|xz|bz2|lz)" file;
        in
        if matched == null then null else builtins.head matched;
      include = version: builtins.match "[0-9]+(\\.[0-9]+)*" version != null;
    };
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://mirrors.kernel.org/gnu/sed/sed-${version}.tar.xz";
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
  recipes.gnused = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

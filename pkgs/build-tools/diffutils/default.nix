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
        builder = ./build-3.10.nix;
        deps = {
          coreutils = tvp.packages.coreutils;
        };
      };
      releases = {
        "3.10" = "sha256-kOXpPMck5OvhLt6A3xY0Bjx6hVaSaFkZv+YLVWyb0J4=";
        "3.11" = "sha256-pz7wX+N91YX32HBo5KBjl2BBn4EBOL11xh3aofniEx4=";
      };
    }
    {
      def = {
        builder = ./build-3.12.nix;
        deps = {
          coreutils = tvp.packages.coreutils;
        };
      };
      releases = {
        "3.12" = "sha256-fIt/n8hgkUH96pzs6FJJ0whiQ5H/Yd7a9Sj8szdyff0=";
      };
    }
  ];
  pname = "diffutils";
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    packageMeta.upstream = {
      type = "directory-index";
      url = "https://mirrors.kernel.org/gnu/diffutils/";
      # Capture whole filenames, including any README, signature or diff suffix.
      # Normalising a matched prefix would falsely count those as archives.
      pattern = ''[^"<>/[:space:]]+\.tar\.[^"<>/[:space:]]+'';
      normalise =
        file:
        let
          archive = builtins.match "diffutils-([0-9]+(\\.[0-9]+)*)\\.tar\\.(gz|xz|bz2)" file;
        in
        if archive == null then null else builtins.head archive;
    };
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://mirrors.kernel.org/gnu/diffutils/diffutils-${version}.tar.xz";
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
  recipes.diffutils = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

{ tvp, ... }:
let
  full = tvp.bases.gcc_16.full;
  locale =
    (tvp.lib.tests.fixtures.forBase {
      builder = tvp.builder;
      base = full;
    }).gnuLocale;
  pname = "gnutar";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-1.32-native.nix;
        deps = {
          acl = tvp.lib.packages.withConstraint {
            reason = "Tar's static three-argument acl_*_at helpers collide with ACL 2.4; retain the supported 2.3 API line.";
          } tvp.packages.acl_2_3;
          attr = tvp.packages.attr_2;
        };
      };
      releases = {
        "1.32" = "sha256-0NOuB/EDMjvoCbw+rA3MOG1SxSYkmf4FURrEeIrx/dg=";
        "1.33" = "sha256-Zqg0Sx3IOkEdMRvRVH4BduVswxHyjulKMPhNr7PZBn4=";
        "1.34" = "sha256-Y769JoecXh7qQ1Lw0DyZH5Zq6z3es8dEXJAlaNVBHSg=";
      };
    }
    {
      def = {
        builder = ./build-1.35-native.nix;
        deps = {
          acl = tvp.lib.packages.withConstraint {
            reason = "Tar's static three-argument acl_*_at helpers collide with ACL 2.4; retain the supported 2.3 API line.";
          } tvp.packages.acl_2_3;
          attr = tvp.packages.attr_2;
        };
      };
      releases = {
        "1.35" = "sha256-TWL/NzQux67XSFNTI5MMfPlKz3HDWRiCsmp+pQ8+3BY=";
      };
    }
  ];
  testDeps = {
    inherit locale;
    gzip = tvp.packages.gzip;
    bzip2 = tvp.packages.bzip2_1;
    xz = tvp.packages.xz_5;
    zstd = tvp.packages.zstd_1;
  };
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable testDeps;

    source = tvp.lib.sources.directory {
      url = "https://mirrors.kernel.org/gnu/tar/";
      archive = "tar-{version}.tar.xz";
      discovery = import ./upstream.nix;
    };
    tests = import ./tests;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes."gnutar" = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

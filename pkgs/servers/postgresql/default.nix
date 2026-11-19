{ tvp, ... }:
let
  pname = "postgresql";
  releaseDirectory = "https://ftp.postgresql.org/pub/source/";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps = {
          icu = tvp.packages.icu_74;
          keyutils = tvp.packages.keyutils_1;
          krb5 = tvp.packages.krb5_1;
          libxml2 = tvp.packages.libxml2_2;
          openssl = tvp.packages.openssl_3_0;
          readline = tvp.packages.readline_8;
          tzdata = tvp.packages.tzdata;
          zlib = tvp.packages.zlib_1;
          zstd = tvp.packages.zstd_1;
        };
      };
      releases."16.16" = "sha256-nVzYYzBDt1dA1dWXSca3Nl5q61PEcJixpegLsY+HiBo=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url = version: "${releaseDirectory}v${version}/postgresql-${version}.tar.bz2";
      discovery = {
        type = "directory-index";
        url = releaseDirectory;
        pattern = ''href="v[0-9]+[.][0-9]+/"'';
        normalise =
          link:
          let
            match = builtins.match ''href="v([0-9]+[.][0-9]+)/"'' link;
          in
          if match == null then null else builtins.head match;
      };
    };
    tests = import ./tests.nix;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.postgresql = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

{ tvp, ... }:
let
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-4.0.0.nix;
        deps.file = tvp.packages.file;
      };
      releases."4.0.0" = "sha256-lCRFwyRbInMP1Bpnp8XCMdEcsbmTa5wPdjNPt9C0Row=";
    }
    {
      def = {
        builder = ./build-4.0.1.nix;
      };
      releases."4.0.1" = "sha256-ltM6u0uwBwx74P7UJGzThBYYgyX4IEaCFEcZOFRbGsg=";
    }
  ];
  pname = "mpdecimal";
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;

    source = tvp.lib.sources.directory {
      url = "https://www.bytereef.org/software/mpdecimal/releases/";
      archive = "mpdecimal-{version}.tar.gz";
      discovery = {

        url = "https://www.bytereef.org/mpdecimal/download.html";
        pattern = "mpdecimal-[0-9][^\"]*\\.tar\\.gz";
        normalise = tvp.lib.versions.fromArchiveName {
          prefix = "mpdecimal-";
          suffixes = [ ".tar.gz" ];
        };
        include = version: builtins.match "[0-9]+(\\.[0-9]+)*" version != null;
      };
    };
    tests = import ./tests;
    testDeps = {
      pkgConfig = tvp.packages.pkg-config;
      sentinel = tvp.lib.tests.fixtures.sentinel;
      alternateSource = tvp.lib.tests.fixtures.alternateSource;
    };
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.mpdecimal = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

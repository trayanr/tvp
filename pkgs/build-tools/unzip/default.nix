{ tvp, ... }:
let
  pname = "unzip";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-6.0-native.nix;

        opts.buildFeatures = {
          cflags = "-fcommon -std=gnu17 -Wno-error=implicit-int -Wno-error=implicit-function-declaration";
          hardeningDisable = [ "format" ];
        };
      };
      releases = {
        "6.0" = "sha256-A22WmRZG0ESe0KqVLk++IbR2zplKvCduSdMOaGcIvTc=";
      };
    }
  ];
  testDeps = {
    zip = tvp.packages.zip;
  };
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable testDeps;
    source = tvp.lib.sources.archive {
      url = "https://downloads.sourceforge.net/infozip/unzip60.tar.gz";
      discovery = {
        # Compact source names encode 60 as 6.0 and 552 as 5.52.
        type = "directory-index";
        url = "https://sourceforge.net/projects/infozip/rss?path=/";
        pattern = "/unzip[0-9]{2,3}\\.(tar\\.gz|tgz|zip)/download";
        normalise =
          file:
          let
            match = builtins.match "/unzip([0-9])([0-9]{1,2})\\.(tar\\.gz|tgz|zip)/download" file;
          in
          if match == null then null else "${builtins.elemAt match 0}.${builtins.elemAt match 1}";
      };
    };
    tests = import ./tests;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes."unzip" = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

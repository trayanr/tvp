{ tvp, ... }:
let
  pname = "zip";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-3.0-native.nix;
        deps = {
          bzip2 = tvp.packages.bzip2_1;
        };
        opts.buildFeatures = {
          cflags = "-Wno-error=implicit-function-declaration -Wno-error=implicit-int";
          hardeningDisable = [ "format" ];
        };
      };
      releases = {
        "3.0" = "sha256-8Oi7H5t+sLAShUlaJpnfOkt2Z4TBdlqPGu7fY8CAY2k=";
      };
    }
  ];
  testDeps = {
    unzip = tvp.packages.unzip;
  };
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable testDeps;
    source = tvp.lib.sources.archive {
      url = "https://downloads.sourceforge.net/infozip/zip30.tar.gz";
      discovery = {
        # The project's RSS inventory includes current and archived source files.
        type = "directory-index";
        url = "https://sourceforge.net/projects/infozip/rss?path=/";
        pattern = "/zip[0-9]{2,3}\\.(tar\\.gz|tgz|zip)/download";
        normalise =
          file:
          let
            match = builtins.match "/zip([0-9])([0-9]{1,2})\\.(tar\\.gz|tgz|zip)/download" file;
          in
          if match == null then null else "${builtins.elemAt match 0}.${builtins.elemAt match 1}";
      };
    };
    tests = import ./tests;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes."zip" = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

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
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://downloads.sourceforge.net/infozip/zip30.tar.gz";
        inherit sha256;
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

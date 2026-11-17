{ tvp, ... }:
let
  pname = "linux-headers";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-6.9-native.nix;

      };
      releases = {
        "6.9" = "sha256-JPoB+5icej4oRT8Rd5kWhxN2bhGcU4HawwEV8Y8mgUk=";
      };
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.directory {
      url = "https://cdn.kernel.org/pub/linux/kernel/v6.x/";
      archive = "linux-{version}.tar.xz";
    };
    tests = import ./tests;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes."linux-headers" = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

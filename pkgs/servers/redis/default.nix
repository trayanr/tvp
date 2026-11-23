{ tvp, ... }:
let
  pname = "redis";
  versionTable = tvp.lib.packages.mkTable [
    {
      def.builder = ./build-8.10.3.nix;
      releases = {
        "8.10.3" = "sha256-7d53j2ve51geQvwTnKngfigiISCS91AfmZiWVuNinQI=";
        "8.12.0" = "sha256-sBAKh5stRdyX2P2pQRJ2CdZI+JEwCNsbZaL3KorjbIs=";
      };
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.directory {
      url = "https://download.redis.io/releases/";
      archive = "redis-{version}.tar.gz";
      discovery.include = version: builtins.match "[0-9]+[.][0-9]+[.][0-9]+" version != null;
    };
    tests = import ./tests.nix;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.redis = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

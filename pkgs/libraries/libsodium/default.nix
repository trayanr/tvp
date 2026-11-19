{ tvp, ... }:
let
  pname = "libsodium";
  versionTable = tvp.lib.packages.mkTable [
    {
      def.builder = ./build.nix;
      releases."1.0.22" = "sha256-rb3Y8WFJ6BrGB4oDrKb8A7WSuJ73te2DhBwIYZG+M0k=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.directory {
      url = "https://download.libsodium.org/libsodium/releases/";
      archive = "libsodium-{version}.tar.gz";
      discovery.include = version: builtins.match "[0-9]+([.][0-9]+)+" version != null;
    };
    tests = import ./tests.nix;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.${pname} = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

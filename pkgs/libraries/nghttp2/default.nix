{ tvp, ... }:
let
  pname = "nghttp2";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-1.70.0-native.nix;
      };
      releases = {
        "1.70.0" = "sha256-4FyxOI6so4MK3tTM8gBEtuGsGmFBHcyhGwQ3xChci8I=";
      };
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url =
        version:
        "https://github.com/nghttp2/nghttp2/releases/download/v${version}/nghttp2-${version}.tar.xz";
      discovery = {
        type = "git-tags";
        url = "https://github.com/nghttp2/nghttp2";
        prefix = "v";
        include = version: builtins.match "[0-9]+(\\.[0-9]+)+" version != null;
      };
    };
    tests = import ./tests;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes."nghttp2" = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

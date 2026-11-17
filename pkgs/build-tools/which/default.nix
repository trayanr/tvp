{ tvp, ... }:
let
  pname = "which";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-2.21-native.nix;

      };
      releases = {
        "2.21" = "sha256-9KJFuUEks3fYtJZGv0IfkVXTaqdhS26/g3BdP/x26q0=";
      };
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.directory {
      url = "https://mirrors.kernel.org/gnu/which/";
      archive = "which-{version}.tar.gz";
    };
    tests = import ./tests;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes."which" = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

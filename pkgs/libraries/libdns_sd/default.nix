{ tvp, ... }:
let
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;

      };
      releases."2881.120.11" = "sha256-9mXPArXJMPm3D7ObdWfwPdghmXWUxWzjmQmOqgNy+xU=";
    }
  ];
  pname = "libdns_sd";
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://github.com/apple-oss-distributions/mDNSResponder/archive/refs/tags/mDNSResponder-${version}.tar.gz";
        inherit sha256;
      };
    tests = import ./tests/owned.nix;

  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.libdns_sd = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

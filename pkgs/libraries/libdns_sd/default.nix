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
    source = tvp.lib.sources.directory {
      url = "https://github.com/apple-oss-distributions/mDNSResponder/archive/refs/tags/";
      archive = "mDNSResponder-{version}.tar.gz";
      discovery = {
        type = "git-tags";
        url = "https://github.com/apple-oss-distributions/mDNSResponder";
        prefix = "mDNSResponder-";
        include = version: builtins.match "[0-9]+(\\.[0-9]+)+" version != null;
      };
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

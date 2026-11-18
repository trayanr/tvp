{ tvp, ... }:
let
  pname = "freetds";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps.openssl = tvp.packages.openssl_3;
      };
      releases."1.5.21" = "sha256-NDxpNhgBKDgYdQ1m+CSmVfTEg0RkPrJT4rErLc9QoOc=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.directory {
      url = "https://www.freetds.org/files/stable/";
      archive = "freetds-{version}.tar.gz";
      discovery.include = version: builtins.match "[0-9]+(\\.[0-9]+){2}" version != null;
    };
    tests = import ./tests.nix;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.freetds = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

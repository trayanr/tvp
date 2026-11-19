{ tvp, ... }:
let
  pname = "unixodbc";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;

      };
      releases."2.3.14" = "sha256-TigU3j4B/DCwufdeg7taupGrA4TulRKGUEu3AgVSR3E=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.directory {
      url = "https://www.unixodbc.org/";
      archive = "unixODBC-{version}.tar.gz";
    };
    tests = import ./tests.nix;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.unixodbc = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

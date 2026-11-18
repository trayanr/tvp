{ tvp, ... }:
let
  pname = "sqliteodbc";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps = {
          sqlite = tvp.packages.sqlite_3;
          unixodbc = tvp.packages.unixodbc;
        };
      };
      releases."0.99991" = "sha256-TZStuNPN4fqUoorrDfzHvnMUW8383z1eIlQ02zHcilw=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.directory {
      url = "https://ch-werner.hier-im-netz.de/sqliteodbc/";
      archive = "sqliteodbc-{version}.tar.gz";
    };
    tests = import ./tests.nix;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.sqliteodbc = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

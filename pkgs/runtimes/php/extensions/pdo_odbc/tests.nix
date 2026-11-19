{ tvp }:
{
  package,
  lib,
  context,
}:
let
  runtime = import ../../with-extensions.nix {
    inherit lib tvp;
    php = package.php;
    extensions = [ package ];
  };
  inherit (package.tvp.declaredTestDependencies) unixodbc sqliteodbc;
in
context.mkSuite {
  inherit package;
  tools = [ runtime ];
  tests = {
    load = {
      script = ''
        ${runtime}/bin/php -r '
          if (!in_array("odbc", PDO::getAvailableDrivers(), true)) {
            throw new RuntimeException("PDO did not register the ODBC driver");
          }
          echo phpversion("pdo_odbc");
        '
      '';
      expected = package.version;
    };
    roundtrip = {
      script = ''
        export ODBCSYSINI="$PWD" ODBCINSTINI=odbcinst.ini ODBCINI="$PWD/odbc.ini"
        ${unixodbc}/bin/odbcinst -i -d -f ${sqliteodbc}/share/sqliteodbc/odbcinst.ini >&2
        printf '[tvp_fixture]\nDriver=SQLite3\nDatabase=%s/fixture.sqlite\n' "$PWD" > "$ODBCINI"
        ${runtime}/bin/php ${./roundtrip.php}
      '';
      expected = "pdo-odbc-roundtrip";
    };
  };
}

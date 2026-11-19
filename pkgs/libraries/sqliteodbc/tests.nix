{ package, context, ... }:
let
  unixodbc = package.specification.unixodbc;
in
context.mkSuite {
  inherit package;
  tests.query = {
    script = ''
      export ODBCSYSINI="$PWD" ODBCINSTINI=odbcinst.ini ODBCINI="$PWD/odbc.ini"
      ${unixodbc}/bin/odbcinst -i -d -f ${package}/share/sqliteodbc/odbcinst.ini >&2
      printf '[tvp_fixture]\nDriver=SQLite3\nDatabase=%s/fixture.sqlite\n' "$PWD" > "$ODBCINI"
      printf 'SELECT %s;\n' 42 | ${unixodbc}/bin/isql -b -d, tvp_fixture
    '';
    expected = "42";
  };
}

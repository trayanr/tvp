{
  package,
  context,
  lib,
}:
let
  bin = "${package}/bin";
  inherit (package.specification.base) tools;
  query = ''
    CREATE TEMPORARY TABLE smoke (value INT NOT NULL) ENGINE=InnoDB;
    INSERT INTO smoke VALUES (42);
    SELECT value FROM smoke;
  '';
in
context.mkSuite {
  inherit package;
  tools = [
    package
    tools.gawk
    tools.sed
  ];
  tests = {
    version = {
      script = ''
        for tool in mariadbd mariadb; do
          case "$("${bin}/$tool" --version)" in
            *' ${package.version}-MariaDB'*) ;;
            *) exit 1 ;;
          esac
        done
        printf '%s\n' ${lib.escapeShellArg package.version}
      '';
      expected = package.version;
    };
    roundtrip = {
      script = ''
        ${tools.bash}/bin/bash ${./with-test-server.sh} ${package} \
          ${tools.bash}/bin/bash -c '
            exec "$1" --no-defaults --protocol=socket --socket="$TVP_MYSQL_SOCKET" \
              --user=tvp_smoke --password=tvp-local-fixture --database=tvp_smoke \
              --batch --skip-column-names --execute="$2"
          ' mariadb-smoke ${bin}/mariadb ${lib.escapeShellArg query}
      '';
      expected = "42";
    };
  };
}

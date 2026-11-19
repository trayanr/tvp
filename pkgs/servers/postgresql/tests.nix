{ package, context, ... }:
let
  bin = "${package}/bin";
  inherit (package.specification.base) tools;
in
context.mkSuite {
  inherit package;
  tools = [ package ];
  libraries = [ package ];
  tests = {
    client = {
      tools = [ tools.pkg-config ];
      script = ''
        test "$(${bin}/pg_config --includedir)" = "${package}/include"
        test "$(${bin}/pg_config --libdir)" = "${package}/lib"
        test -f "$(${bin}/pg_config --pgxs)"
        "$CC" ${./client.c} $(pkg-config --cflags --libs libpq) -o consumer
        ./consumer
      '';
      expected = package.version;
    };
    roundtrip = {
      script = ''
        ${tools.bash}/bin/bash ${./with-test-server.sh} ${package} ${bin}/psql \
          -XAt -v ON_ERROR_STOP=1 -U tvp_smoke -d postgres \
          -c "SELECT extract(epoch FROM (timestamp '2024-01-01' AT TIME ZONE 'Europe/Paris'))::bigint"
      '';
      expected = "1704063600";
    };
  };
}

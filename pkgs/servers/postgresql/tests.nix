{
  package,
  lib,
  context,
  ...
}:
let
  bin = "${package}/bin";
  inherit (package.specification.base) tools;
  inherit (package.tvp) features;
  # PostgreSQL 19 disables JIT by default, so exercise the provider explicitly.
  enableJit = lib.optionalString (lib.versionAtLeast package.version "19") "SET jit = on;\n";
in
context.mkSuite {
  inherit package;
  tools = [ package ];
  libraries = [ package ];
  tests = {
    cli = {
      script = ''
        for tool in psql pg_dump pg_restore; do
          test "$("$tool" --version)" = "$tool (PostgreSQL) ${package.version}"
        done
        printf cli-ok
      '';
      expected = "cli-ok";
    };
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
    integrations = {
      tools = [ tools.grep ];
      script = ''
        config="$("${bin}/pg_config" --includedir-server)/pg_config.h"
        grep -Fxq '#define USE_LDAP 1' "$config"
        grep -Fxq '#define USE_PAM 1' "$config"
        grep -Fxq '#define ENABLE_NLS 1' "$config"
        ${lib.optionalString features.numa ''
          grep -Fxq '#define USE_LIBNUMA 1' "$config"
        ''}
        ${tools.bash}/bin/bash ${./with-test-server.sh} ${package} ${bin}/psql \
          -XAtq -v ON_ERROR_STOP=1 -U tvp_smoke -d postgres -f - <<'SQL'
        CREATE EXTENSION plperl;
        CREATE EXTENSION plpython3u;
        CREATE EXTENSION pltcl;
        CREATE EXTENSION xml2;
        CREATE EXTENSION "uuid-ossp";
        CREATE FUNCTION perl_value() RETURNS integer LANGUAGE plperl AS $$return 4;$$;
        CREATE FUNCTION python_value() RETURNS integer LANGUAGE plpython3u AS $$return 5$$;
        CREATE FUNCTION tcl_value() RETURNS integer LANGUAGE pltcl AS $$return 6$$;
        SELECT perl_value(), python_value(), tcl_value();
        SELECT xslt_process(
          '<data><value>7</value></data>',
          '<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0"><xsl:output method="text"/><xsl:template match="/"><xsl:value-of select="/data/value"/></xsl:template></xsl:stylesheet>'
        );
        SELECT uuid_generate_v5(uuid_ns_dns(), 'postgresql.org');
        ${lib.optionalString features.lz4 ''
          CREATE TABLE lz4_data (value text COMPRESSION lz4);
          INSERT INTO lz4_data VALUES (repeat('tvp-', 4096));
          SELECT pg_column_compression(value) FROM lz4_data;
        ''}
        ${lib.optionalString features.jit ''
          ${enableJit}SELECT pg_jit_available();
        ''}
        SQL
      '';
      expected = lib.concatStringsSep "\n" (
        [
          "4|5|6"
          "7"
          "bc1c2b7f-cb7d-5fd7-8575-14d84d987e15"
        ]
        ++ lib.optional features.lz4 "lz4"
        ++ lib.optional features.jit "t"
      );
    };
  };
}

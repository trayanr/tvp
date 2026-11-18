{
  package,
  lib,
  context,
}:
context.mkSuite {
  inherit package;
  libraries = [ package ];
  tools = [ package.specification.base.tools.grep ];
  tests = {
    dblib = {
      # The consumer linker needs FreeTDS's OpenSSL dependency in its search path.
      libraries = [
        package
        package.specification.openssl
      ];
      script = ''
        cc ${./dblib.c} -lsybdb -o dblib
        ./dblib
      '';
      expected = "dblib-ready";
    };
    tsql = {
      script = ''
        ${package}/bin/tsql -C > settings
        grep -Fx -- "$(printf '%35s: %s' Version ${lib.escapeShellArg "freetds v${package.version}"})" settings >/dev/null
        grep -Eq '^[[:space:]]*OpenSSL: yes$' settings
        grep -Eq '^[[:space:]]*Sybase binary compatibility: yes$' settings
        grep -F -- ${lib.escapeShellArg "freetds.conf directory: ${package}/etc"} settings >/dev/null
        test -r ${package}/etc/freetds.conf
        printf '%s\n' tsql-ready
      '';
      expected = "tsql-ready";
    };
  };
}

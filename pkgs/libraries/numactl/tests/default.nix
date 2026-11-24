{
  package,
  lib,
  context,
}:
let
  inherit (package.specification) installedInterface;
  inherit (package.specification.base.tools) grep pkg-config;
in
context.mkSuite {
  inherit package;
  libraries = [ package ];
  tests = {
    cli = {
      tools = [ grep ];
      script = ''
        ${lib.optionalString installedInterface.cliVersion ''
          test "$(numactl --version)" = ${lib.escapeShellArg package.version}
        ''}
        status=0
        numactl --tvp-invalid-option > usage 2>&1 || status=$?
        test "$status" = 1
        grep -Fq 'usage: numactl' usage
        test -x "${package}/bin/numastat"
        printf cli-ok
      '';
      expected = "cli-ok";
    };
    consumer = {
      tools = lib.optional installedInterface.pkgconfig pkg-config;
      script = ''
        test -f "${package}/include/numaif.h"
        ${
          if installedInterface.pkgconfig then
            ''
              test "$(pkg-config --modversion numa)" = ${lib.escapeShellArg package.version}
              "$CC" ${./consumer.c} $(pkg-config --cflags --libs numa) -o consumer
            ''
          else
            ''
              "$CC" -I"${package}/include" ${./consumer.c} -L"${package}/lib" -lnuma -o consumer
            ''
        }
        ./consumer
        ${lib.optionalString installedInterface.static ''
          test -s "${package}/lib/libnuma.a"
        ''}
        printf consumer-ok
      '';
      expected = "consumer-ok";
    };
  };
}

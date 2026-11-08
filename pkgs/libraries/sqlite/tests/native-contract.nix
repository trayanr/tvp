{ package }:
let
  deps = package.tvp.deps;
  tcl = deps.tcl;
  sqlite = package;
in
package.testContext.mkSuite {
  inherit package;
  libraries = [ package ];
  tools = package.specification.environment.tools ++ [ deps.binutils ];
  tests = {
    shared-consumer = {
      script = ''
        export PKG_CONFIG_LIBDIR=${package}/lib/pkgconfig
        "$CC" ${./fixtures/contracts.c} $(pkg-config --cflags --libs sqlite3) -lm -o consumer
        LD_TRACE_LOADED_OBJECTS=1 ./consumer >&2
        LD_TRACE_LOADED_OBJECTS=1 ./consumer | grep -F '${package}/lib/libsqlite3.so' >&2
        ./consumer
      '';
      expected = "contracts 3.53.4";
    };
    static-consumer = {
      script = ''
        export PKG_CONFIG_LIBDIR=${package}/lib/pkgconfig
        "$CC" ${./fixtures/contracts.c} ${package}/lib/libsqlite3.a $(pkg-config --libs-only-other --libs-only-L --static sqlite3) -lm -o consumer
        if readelf -d consumer | grep -F 'libsqlite3.so'; then exit 1; fi
        ./consumer
      '';
      expected = "contracts 3.53.4";
    };
    cpp-header = {
      script = ''
        "$CXX" -x c++ ${./fixtures/version.c} -lsqlite3 -o consumer
        ./consumer
      '';
      expected = "3.53.4";
    };
    load-extension = {
      script = ''
        "$CC" -shared -fPIC ${./fixtures/extension.c} -o extension.so
        ${package}/bin/sqlite3 :memory: ".load $PWD/extension.so" 'select tvp_extension();'
      '';
      expected = "extension works";
    };
    discovery = {
      script = ''
        mkdir empty
        if PKG_CONFIG_LIBDIR="$PWD/empty" PKG_CONFIG_PATH= pkg-config --exists sqlite3; then exit 1; fi
        export PKG_CONFIG_LIBDIR=${package}/lib/pkgconfig PKG_CONFIG_PATH=
        test "$(pkg-config --variable=prefix sqlite3)" = '${package}'
        test "$(pkg-config --modversion sqlite3)" = '${package.version}'
        test "$(pkg-config --libs --static sqlite3)" = '-L${package}/lib -lsqlite3 -lm '
        printf discovered
      '';
      expected = "discovered";
    };
    tcl-package = {
      script = ''
        env -u TCLLIBPATH -u LD_LIBRARY_PATH ${tcl}/bin/tclsh ${./fixtures/tcl-binding.tcl} ${package} positive
      '';
      expected = "tcl 8.6.18 sqlite 3.53.4";
    };
    tcl-explicit-load = {
      script = ''
        env -u TCLLIBPATH -u LD_LIBRARY_PATH ${tcl}/bin/tclsh ${./fixtures/tcl-binding.tcl} ${package} explicit
      '';
      expected = "tcl 8.6.18 sqlite 3.53.4";
    };
    tcl-bundled-control = {
      script = ''
        env -u TCLLIBPATH -u LD_LIBRARY_PATH ${tcl}/bin/tclsh ${./fixtures/tcl-binding.tcl} ${package} negative
      '';
      expected = "bundled 3.53.0 retained";
    };
  };
}

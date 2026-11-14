{ package }:
package.testContext.mkSuite {
  inherit package;
  libraries = [ package ];
  tools = package.specification.environment.tools ++ [ package.tvp.deps.binutils ];
  tests =
    {
      shared-consumer = {
        script = ''
          "$CC" ${./fixtures/query.c} -lsqlite3 -o consumer
          LD_TRACE_LOADED_OBJECTS=1 ./consumer | grep -F '${package}/lib/libsqlite3.so' >&2
          ./consumer
        '';
        expected = "tvp";
      };
      static-consumer = {
        script = ''
          "$CC" ${./fixtures/query.c} ${package}/lib/libsqlite3.a -lm -ldl -lpthread -o consumer
          if readelf -d consumer | grep -F 'libsqlite3.so'; then exit 1; fi
          ./consumer
        '';
        expected = "tvp";
      };
      cpp-header = {
        script = ''
          "$CXX" -x c++ ${./fixtures/version.c} -lsqlite3 -o consumer
          ./consumer
        '';
        expected = package.tvp.reportedVersion;
      };
    }
    // (
      if builtins.compareVersions package.version "3.1.0" >= 0 then
        {
          tcl-extension = {
            script = ''
              env -u TCLLIBPATH -u LD_LIBRARY_PATH ${package.tvp.deps.tcl}/bin/tclsh ${./fixtures/ordinary-tcl.tcl} ${package}
            '';
            expected = "tvp";
          };
        }
      else
        { }
    );
}

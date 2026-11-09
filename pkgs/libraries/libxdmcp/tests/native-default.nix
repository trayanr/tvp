{
  pkgs,
  tvpLib,
  package,
}:
let
  spec = package.specification;
in
package.testContext.mkSuite {
  inherit package;
  libraries = [ package ];
  tools = [ spec.pkgConfig ];
  tests = {
    api = {
      script = ''
        "$CC"  $(pkg-config --cflags xdmcp) ${./fixtures/api.c}  $(pkg-config --libs xdmcp) -o consumer
        ./consumer
      '';
      expected = "api-ok";
    };
    cxx = {
      script = ''
        "$CXX" -x c++ $(pkg-config --cflags xdmcp) ${./fixtures/api.c} -x none $(pkg-config --libs xdmcp) -o consumer
        ./consumer
      '';
      expected = "api-ok";
    };
    static = {
      script = ''
        "$CC"  $(pkg-config --cflags xdmcp) ${./fixtures/api.c}  ${package}/lib/libXdmcp.a $(pkg-config --static --libs xdmcp) -o consumer
        ./consumer
      '';
      expected = "api-ok";
    };
    consumer = {
      script = ''"$CC" -I${package}/include -I${spec.xorgproto}/include ${./fixtures/consumer.c} -L${package}/lib -lXdmcp -ldl -o consumer; ./consumer ${package}/lib/libXdmcp.so'';
      expected = "loaded";
    };
    discovery = {
      script = ''
        test -s ${package}/lib/libXdmcp.a
        test -e ${package}/lib/libXdmcp.so
        pkg-config --exists --print-errors xdmcp
        pkg-config --modversion xdmcp
      '';
      expected = package.version;
    };
  };
}

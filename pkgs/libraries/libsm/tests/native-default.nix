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
        "$CC"  $(pkg-config --cflags sm) ${./fixtures/api.c}  $(pkg-config --libs sm) -o consumer
        ./consumer
      '';
      expected = "api-ok";
    };
    cxx = {
      script = ''
        "$CXX" -x c++ $(pkg-config --cflags sm) ${./fixtures/api.c} -x none $(pkg-config --libs sm) -o consumer
        ./consumer
      '';
      expected = "api-ok";
    };
    static = {
      script = ''
        "$CC"  $(pkg-config --cflags sm) ${./fixtures/api.c}  ${package}/lib/libSM.a $(pkg-config --static --libs sm) -o consumer
        ./consumer
      '';
      expected = "api-ok";
    };
    consumer = {
      script = ''"$CC" -I${package}/include -I${spec.libice}/include -I${spec.xorgproto}/include -I${spec.xtrans}/include ${./fixtures/consumer.c} -L${package}/lib -lSM -ldl -o consumer; ./consumer ${package}/lib/libSM.so'';
      expected = "loaded";
    };
    discovery = {
      script = ''
        test -s ${package}/lib/libSM.a
        test -e ${package}/lib/libSM.so
        pkg-config --exists --print-errors sm
        pkg-config --modversion sm
      '';
      expected = package.version;
    };
  };
}

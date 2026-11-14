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
        "$CC"  $(pkg-config --cflags ice) ${./fixtures/api.c}  $(pkg-config --libs ice) -o consumer
        ./consumer
      '';
      expected = "api-ok";
    };
    cxx = {
      script = ''
        "$CXX" -x c++ $(pkg-config --cflags ice) ${./fixtures/api.c} -x none $(pkg-config --libs ice) -o consumer
        ./consumer
      '';
      expected = "api-ok";
    };
    static = {
      script = ''
        "$CC"  $(pkg-config --cflags ice) ${./fixtures/api.c}  ${package}/lib/libICE.a $(pkg-config --static --libs ice) -o consumer
        ./consumer
      '';
      expected = "api-ok";
    };
    consumer = {
      script = ''"$CC" -I${package}/include -I${spec.xorgproto}/include -I${spec.xtrans}/include ${./fixtures/consumer.c} -L${package}/lib -lICE -ldl -o consumer; ./consumer ${package}/lib/libICE.so'';
      expected = "loaded";
    };
    discovery = {
      script = ''
        test -s ${package}/lib/libICE.a
        test -e ${package}/lib/libICE.so
        pkg-config --exists --print-errors ice
        pkg-config --modversion ice
      '';
      expected = package.version;
    };
  };
}

// {
  upstream = import ./upstream.nix { inherit package; };
}

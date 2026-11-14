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
        "$CC"  $(pkg-config --cflags xau) ${./fixtures/api.c}  $(pkg-config --libs xau) -o consumer
        ./consumer
      '';
      expected = "api-ok";
    };
    cxx = {
      script = ''
        "$CXX" -x c++ $(pkg-config --cflags xau) ${./fixtures/api.c} -x none $(pkg-config --libs xau) -o consumer
        ./consumer
      '';
      expected = "api-ok";
    };
    static = {
      script = ''
        "$CC"  $(pkg-config --cflags xau) ${./fixtures/api.c}  ${package}/lib/libXau.a $(pkg-config --static --libs xau) -o consumer
        ./consumer
      '';
      expected = "api-ok";
    };
    consumer = {
      script = ''"$CC" -I${package}/include -I${spec.xorgproto}/include ${./fixtures/consumer.c} -L${package}/lib -lXau -ldl -o consumer; ./consumer ${package}/lib/libXau.so'';
      expected = "loaded";
    };
    discovery = {
      script = ''
        test -s ${package}/lib/libXau.a
        test -e ${package}/lib/libXau.so
        pkg-config --exists --print-errors xau
        pkg-config --modversion xau
      '';
      expected = package.version;
    };
  };
}

// {
  upstream = import ./upstream.nix { inherit package; };
}

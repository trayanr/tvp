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
        "$CC"  $(pkg-config --cflags xcb xcb-render xcb-xinput xcb-xkb) ${./fixtures/api.c}  $(pkg-config --libs xcb xcb-render xcb-xinput xcb-xkb) -o consumer
        ./consumer
      '';
      expected = "api-ok";
    };
    cxx = {
      script = ''
        "$CXX" -x c++ $(pkg-config --cflags xcb xcb-render xcb-xinput xcb-xkb) ${./fixtures/api.c} -x none $(pkg-config --libs xcb xcb-render xcb-xinput xcb-xkb) -o consumer
        ./consumer
      '';
      expected = "api-ok";
    };
    static = {
      script = ''
        "$CC"  $(pkg-config --cflags xcb xcb-render xcb-xinput xcb-xkb) ${./fixtures/api.c}  ${package}/lib/libxcb.a $(pkg-config --static --libs xcb xcb-render xcb-xinput xcb-xkb) -o consumer
        ./consumer
      '';
      expected = "api-ok";
    };
    consumer = {
      script = ''"$CC" -I${package}/include -I${spec.libxau}/include -I${spec.libxdmcp}/include -I${spec.xorgproto}/include ${./fixtures/consumer.c} -L${package}/lib -lxcb -ldl -o consumer; ./consumer ${package}/lib/libxcb.so'';
      expected = "loaded";
    };
    discovery = {
      script = ''
        test -s ${package}/lib/libxcb.a
        test -e ${package}/lib/libxcb.so
        pkg-config --exists --print-errors xcb
        pkg-config --modversion xcb
      '';
      expected = package.version;
    };
    generation = {
      tools = [
        spec.pkgConfig
        spec.generatorPython
      ];
      script = ''
        export PYTHONPATH=${spec.xcb-proto.development.pythonModuleDirectory}
        ${spec.generatorPython}/bin/python3 -B ${../../xcb-proto/tests/fixtures/consumer.py} ${spec.xcb-proto}/share/xcb/xproto.xml
        for extension in render randr xinput xkb glx shape shm sync present; do
          test -s ${package}/include/xcb/$extension.h
          test -e ${package}/lib/libxcb-$extension.so
        done
      '';
      expected = "xcbgen-ok";
    };
  };
}

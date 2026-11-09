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
        "$CC"  $(pkg-config --cflags x11) ${./fixtures/api.c}  $(pkg-config --libs x11) -o consumer
        ./consumer
      '';
      expected = "api-ok";
    };
    cxx = {
      script = ''
        "$CXX" -x c++ $(pkg-config --cflags x11) ${./fixtures/api.c} -x none $(pkg-config --libs x11) -o consumer
        ./consumer
      '';
      expected = "api-ok";
    };
    static = {
      script = ''
        "$CC"  $(pkg-config --cflags x11) ${./fixtures/api.c}  ${package}/lib/libX11.a $(pkg-config --static --libs x11) -o consumer
        ./consumer
      '';
      expected = "api-ok";
    };
    consumer = {
      script = ''"$CC" -I${package}/include -I${spec.xorgproto}/include -I${spec.xtrans}/include -I${spec.libxcb}/include -I${spec.libxau}/include -I${spec.libxdmcp}/include ${./fixtures/consumer.c} -L${package}/lib -lX11 -ldl -o consumer; ./consumer ${package}/lib/libX11.so'';
      expected = "loaded";
    };
    discovery = {
      script = ''
        test -s ${package}/lib/libX11.a
        test -e ${package}/lib/libX11.so
        pkg-config --exists --print-errors x11
        pkg-config --modversion x11
      '';
      expected = package.version;
    };
    locale-data = {
      script = ''
        test -s ${package}/share/X11/locale/locale.alias
        test -s ${package}/share/X11/locale/en_US.UTF-8/Compose
        test -s ${package}/share/X11/XErrorDB
        pkg-config --exists x11-xcb xcb xau xdmcp xproto
        printf '%s\n' data-ok
      '';
      expected = "data-ok";
    };
  };
}

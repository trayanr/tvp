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
  libraries = [
    package
    package.tvp.declaredTestDependencies.xorgproto
  ];
  tools = [ spec.pkgConfig ];
  tests = {
    consumer = {
      script = ''
        test -s ${package}/include/X11/Xtrans/Xtrans.h
        test -s ${package}/include/X11/Xtrans/Xtrans.c
        test -s ${package}/include/X11/Xtrans/Xtranssock.c
        test -s ${package}/share/aclocal/xtrans.m4
        pkg-config --modversion xtrans
      '';
      expected = package.version;
    };
    headers = {
      script = ''
        cat > consumer.c <<'EOF'
        #include <sys/types.h>
        #include <sys/socket.h>
        #include <X11/Xtrans/Xtrans.h>
        int main(void) { return 0; }
        EOF
        "$CC" $(pkg-config --cflags xtrans) -c consumer.c -o consumer.o
        "$CXX" -x c++ $(pkg-config --cflags xtrans) -c consumer.c -o consumer-cxx.o
        echo headers-ok
      '';
      expected = "headers-ok";
    };
  };
}

// {
  upstream = import ./upstream.nix { inherit package; };
}

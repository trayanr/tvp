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
    consumer = {
      script = ''"$CC" ${./fixtures/consumer.c} -o consumer; ./consumer'';
      expected = "11.0";
    };
    headers-cxx = {
      script = ''
        cat > consumer.cc <<'EOF'
        #include <X11/X.h>
        #include <X11/Xproto.h>
        #include <X11/extensions/renderproto.h>
        #include <X11/extensions/randrproto.h>
        #include <X11/extensions/XI2proto.h>
        static_assert(X_PROTOCOL == 11, "X11 protocol");
        int main() { return 0; }
        EOF
        "$CXX" consumer.cc -o consumer
        ./consumer
        pkg-config --exists xproto renderproto randrproto inputproto
        echo headers-ok
      '';
      expected = "headers-ok";
    };
  };
}

// {
  upstream = import ./upstream.nix { inherit package; };
}

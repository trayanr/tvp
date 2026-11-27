{ package, context, ... }:
context.mkSuite {
  inherit package;
  tools = [ package.specification.base.tools.pkg-config ];
  libraries = [ package ];
  tests = {
    half = {
      script = ''
        cat > half.cc <<'CPP'
        #include <Imath/half.h>
        int main() {
          volatile float value = 0.5f;
          return float(Imath::half(value)) == value ? 0 : 1;
        }
        CPP
        "$CXX" $(pkg-config --cflags Imath) half.cc -o half $(pkg-config --libs Imath)
        env -i ./half
        printf 'half-ok'
      '';
      expected = "half-ok";
    };
    version = {
      script = "pkg-config --modversion Imath";
      expected = package.version;
    };
  };
}

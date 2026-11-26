{ package, context, ... }:
let
  inherit (package.specification.base) tools;
in
context.mkSuite {
  inherit package;
  tools = [
    tools.diffutils
    tools.pkg-config
  ];
  libraries = [ package ];
  tests = {
    roundtrip = {
      script = ''
        printf '%s\n' 'LZ4 frame round trip' > plain
        lz4 -q plain frame.lz4
        lz4 -qd frame.lz4 result
        cmp plain result
        printf '%s\n' 'round trip'
      '';
      expected = "round trip";
    };
    consumer = {
      script = ''
        cat > consumer.c <<'EOF'
        #include <lz4.h>
        #include <stdio.h>
        int main(void) {
          puts(LZ4_versionString());
          return LZ4_versionNumber() != LZ4_VERSION_NUMBER;
        }
        EOF
        cc $(pkg-config --cflags liblz4) consumer.c $(pkg-config --libs liblz4) -o consumer
        ./consumer
      '';
      expected = package.version;
    };
  };
}

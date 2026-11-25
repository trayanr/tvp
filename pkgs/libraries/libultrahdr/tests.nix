{ package, context, ... }:
let
  inherit (package.specification.base) tools;
in
context.mkSuite {
  inherit package;
  tools = [ tools.pkg-config tools.python ];
  libraries = [ package ];
  tests = {
    pkg-config = {
      script = "pkg-config --modversion libuhdr";
      expected = package.version;
    };
    consumer = {
      script = ''
        cat > consumer.c <<'EOF'
        #include <ultrahdr_api.h>
        #include <stdio.h>
        int main(void) {
          uhdr_codec_private_t *encoder = uhdr_create_encoder();
          uhdr_codec_private_t *decoder = uhdr_create_decoder();
          if (!encoder || !decoder)
            return 1;
          uhdr_release_encoder(encoder);
          uhdr_release_decoder(decoder);
          puts(UHDR_LIB_VERSION_STR);
          return 0;
        }
        EOF
        cc $(pkg-config --cflags libuhdr) consumer.c $(pkg-config --libs libuhdr) -o consumer
        ./consumer
      '';
      expected = package.version;
    };
    jpeg-roundtrip = {
      script = ''
        python3 - <<'PY'
        import struct
        from pathlib import Path

        luma = struct.pack("<1024H", *((64 + (pixel % 32) * 26) << 6 for pixel in range(1024)))
        chroma = struct.pack("<H", 512 << 6) * 512
        Path("hdr.p010").write_bytes(luma + chroma)
        PY
        ultrahdr_app -m 0 -p hdr.p010 -w 32 -h 32 -a 0 -z encoded.jpg >&2
        test -s encoded.jpg
        ultrahdr_app -m 1 -j encoded.jpg -o 3 -O 3 -z decoded.rgba >&2
        test "$(wc -c < decoded.rgba)" -eq 4096
        printf '%s\n' 'Ultra HDR JPEG'
      '';
      expected = "Ultra HDR JPEG";
    };
  };
}

{ package, context, ... }:
context.mkSuite {
  inherit package;
  tools = [
    package.specification.base.tools.pkg-config
    package.specification.base.tools.grep
  ];
  libraries = [
    package
    package.specification.numa
  ];
  tests = {
    depths = {
      script = ''
        cat > depths.c <<'C'
        #include <stdio.h>
        #include <x265.h>
        int main(void) {
          const int depths[] = {8, 10, 12};
          for (unsigned i = 0; i < sizeof(depths) / sizeof(depths[0]); ++i) {
            const x265_api *api = x265_api_get(depths[i]);
            if (api == NULL || api->bit_depth != depths[i]) return 1;
          }
          puts("8 10 12");
          return 0;
        }
        C
        "$CC" $(pkg-config --cflags x265) depths.c -o depths $(pkg-config --libs x265)
        env -i ./depths
      '';
      expected = "8 10 12";
    };
    encode = {
      script = ''
        x265 --version > version 2>&1
        grep -Fq 'encoder version ${package.version}' version
        dd if=/dev/zero of=frame.yuv bs=6144 count=1 status=none
        x265 --input-res 64x64 --fps 1 --frames 1 --preset ultrafast \
          --pools none --frame-threads 1 frame.yuv out.hevc >&2
        test -s out.hevc
        printf 'hevc-ok'
      '';
      expected = "hevc-ok";
    };
  };
}

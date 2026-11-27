{ package, context, ... }:
context.mkSuite {
  inherit package;
  tools = [ package.specification.base.tools.pkg-config ];
  libraries = [ package ] ++ package.specification.environment.libraries;
  tests = {
    version = {
      script = "pkg-config --modversion libheif";
      expected = package.version;
    };
    hevc-roundtrip = {
      script = ''
        {
          printf 'YUV4MPEG2 W64 H64 F1:1 Ip A1:1 C420jpeg\nFRAME\n'
          head -c 2048 /dev/zero | tr '\000' '\060'
          head -c 2048 /dev/zero | tr '\000' '\260'
          head -c 2048 /dev/zero | tr '\000' '\200'
        } > input.y4m
        heif-enc --hevc -e x265 -p x265:pools=none -o picture.heic input.y4m >&2
        "$CC" $(pkg-config --cflags libheif) ${./decode.c} -o decode $(pkg-config --libs libheif)
        env -i ./decode picture.heic
      '';
      expected = "hevc-roundtrip-ok";
    };
  };
}

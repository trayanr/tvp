{ package, context, ... }:
context.mkSuite {
  inherit package;
  libraries = [ package ];
  tests.consumer = {
    tools = [ package.specification.base.tools.pkg-config ];
    script = ''
      "$CC" ${./consumer.c} $(pkg-config --cflags --libs libwebp) -o consumer
      ./consumer
    '';
    expected = package.version;
  };
  tests.commands = {
    tools = [ package.specification.base.tools.grep ];
    libraries = [
      package.specification.jpeg
      package.specification.png
    ];
    script = ''
      "$CC" ${./fixtures.c} -lpng -ljpeg -o fixtures
      ./fixtures write
      cwebp -quiet -lossless input.png -o png.webp
      dwebp -quiet png.webp -o decoded.png
      ./fixtures check
      cwebp -quiet -lossless input.jpg -o jpeg.webp
      webpinfo jpeg.webp > info
      grep -Fx 'No error detected.' info
      img2webp input.png input.jpg -o animated.webp
      webpmux -info animated.webp > animation
      grep -Fx 'Canvas size: 8 x 8' animation
      grep -Fx 'Number of frames: 2' animation
    '';
    expected = "No error detected.\nCanvas size: 8 x 8\nNumber of frames: 2";
  };
}

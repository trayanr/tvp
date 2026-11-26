{ lib, ... }:
let
  check = import ../test.nix { inherit lib; };
in
{
  inputs.imagemagick = args: args.tvp.packages.imagemagick_7;
  configure = final: {
    libraries = [ final.imagemagick ];
  };
  mkTests = package: {
    load = check package {
      name = "image-library";
      script = ''
        ${package.ruby}/bin/ruby -r${
          if lib.versionOlder package.version "2" then "RMagick" else "rmagick"
        } -e '
          image = Magick::Image.new(1, 1)
          abort "ImageMagick image creation failed" unless image.columns == 1 && image.rows == 1
          print "rmagick-loaded"
        '
      '';
      expected = "rmagick-loaded";
    };
  };
}

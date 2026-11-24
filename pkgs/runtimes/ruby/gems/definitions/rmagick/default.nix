{ lib, pkgs, ... }:
let
  library = import ../native-library.nix { inherit lib; };
  check = import ../test.nix { inherit lib; };
  provider =
    name:
    if pkgs == null then
      throw "TVP Ruby rmagick: provide ${name} explicitly or use the full TVP package context"
    else
      pkgs.${name};
in
{
  inputs = {
    imagemagick = _: provider "imagemagick7";
    numactl = _: provider "numactl";
    libc = _: provider "glibc";
  };
  configure = final: {
    libraries = [
      (library final.imagemagick)
      (library final.numactl)
      # The ImageMagick provider needs libmvec from its libc, without mixing its
      # libc headers into the selected Ruby compiler's own SDK.
      (
        final.libc
        // {
          development = {
            includeDirectories = [ ];
            libraryDirectories = [ "${lib.getLib final.libc}/lib" ];
          };
        }
      )
    ];
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

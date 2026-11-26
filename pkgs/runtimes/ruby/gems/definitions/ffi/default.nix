{ lib, ... }:
let
  check = import ../test.nix { inherit lib; };
in
{
  inputs.libffi = args: args.tvp.packages.libffi_3;
  configure = final: {
    libraries = [ final.libffi ];
    buildFlags = [ "--enable-system-libffi" ];
  };
  mkTests = package: {
    load = check package {
      name = "native-memory";
      script = ''
        ${package.ruby}/bin/ruby -rffi -e '
          value = FFI::MemoryPointer.new(:int)
          value.write_int(42)
          abort "FFI memory access failed" unless value.read_int == 42
          print "ffi-loaded"
        '
      '';
      expected = "ffi-loaded";
    };
  };
}

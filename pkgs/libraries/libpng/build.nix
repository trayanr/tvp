{
  tvp,
  lib,
  base,
  src,
  version,
  zlib,
}:
final:
let
  inherit (tvp.builder.forBase final.base) steps outputs tools;
  command = steps.command { environment = final.environment; };
  make = ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash'';
in
{
  pname = "libpng";
  inherit
    base
    src
    version
    zlib
    ;
  inherit (tools) bash coreutils;
  environment = {
    tools = [
      tools.gnumake
      tools.pkg-config
      tools.sed
      tools.grep
      tools.gawk
      tools.diffutils
      tools.findutils
    ];
    libraries = [ final.zlib ];
  };
  runtime.libraries = final.environment.libraries;
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = "xz";
    })
    (steps.prepareAutotools { name = "libpng.prepare"; })
    (command "libpng.configure" ''
      export CONFIG_SHELL=${tools.bash}/bin/bash
      ./configure --prefix="$out" --libdir="$out/lib" --enable-shared --disable-static
    '')
    (command "libpng.build" make)
    (command "libpng.install" "${make} install")
    (steps.split "libpng.finalize")
    (outputs.copyArtifacts { })
    (outputs.relocateText {
      paths = [
        "bin/libpng16-config"
        "lib/libpng16.la"
        "lib/pkgconfig/libpng16.pc"
      ];
    })
    (outputs.shebangs {
      paths = [ "bin" ];
      names = [ "sh" ];
      interpreter = "${tools.bash}/bin/bash";
    })
    (outputs.strip {
      paths = [
        "bin"
        "lib"
      ];
    })
    (outputs.rpaths {
      paths = [
        "bin"
        "lib"
      ];
      libraries = final.runtime.libraries;
    })
    (outputs.development { libraries = [ final.zlib ]; })
    (outputs.checkPaths {
      paths = [
        "bin"
        "lib"
      ];
    })
  ];
  meta = {
    description = "Reference library for reading and writing PNG images";
    homepage = "https://www.libpng.org/pub/png/libpng.html";
    license = lib.licenses.libpng2;
    platforms = [ "x86_64-linux" ];
  };
}

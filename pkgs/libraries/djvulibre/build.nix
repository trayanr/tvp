{
  tvp,
  lib,
  base,
  src,
  version,
  jpeg,
  tiff,
}:
final:
let
  inherit (tvp.builder.forBase final.base) steps outputs tools;
  command = steps.command { environment = final.environment; };
  make = ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash'';
  elfPaths = [
    "bin"
    "lib"
  ];
in
{
  pname = "djvulibre";
  inherit
    base
    src
    version
    jpeg
    tiff
    ;
  inherit (tools) bash coreutils;
  outputs = [ "out" ];
  environment = {
    tools = with tools; [
      gnumake
      gzip
      gawk
      grep
      sed
      diffutils
      findutils
    ];
    libraries = [
      final.jpeg
      final.tiff
    ];
  };
  runtime.libraries = final.environment.libraries;
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = "gzip";
    })
    (steps.prepareAutotools { name = "djvulibre.prepare"; })
    (command "djvulibre.configure" ''
      export CONFIG_SHELL=${tools.bash}/bin/bash
      "$CONFIG_SHELL" ./configure --prefix="$out" --libdir="$out/lib" \
        --enable-shared --disable-static --with-jpeg=${final.jpeg} --with-tiff=${final.tiff}
    '')
    (command "djvulibre.build" make)
    (command "djvulibre.install" "${make} install")
    (steps.split "djvulibre.finalize")
    (outputs.copyArtifacts { outputs = final.outputs; })
    (outputs.libtool { paths = [ "lib" ]; })
    (outputs.relocateText { paths = [ "lib/pkgconfig" ]; })
    (outputs.shebangs {
      paths = [ "bin" ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${tools.bash}/bin/bash";
    })
    (outputs.strip { paths = elfPaths; })
    (outputs.rpaths {
      paths = elfPaths;
      libraries = final.runtime.libraries;
    })
    (outputs.development { libraries = [ ]; })
    (outputs.checkPaths { paths = elfPaths; })
  ];
  meta = {
    description = "DjVu image codec library and command-line tools";
    homepage = "https://djvu.sourceforge.net/";
    license = lib.licenses.gpl2Plus;
    platforms = [ "x86_64-linux" ];
  };
}

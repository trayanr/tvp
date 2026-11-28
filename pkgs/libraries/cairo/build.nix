{
  tvp,
  lib,
  base,
  src,
  version,
  fontconfig,
  freetype,
  glib,
  libpng,
  libx11,
  libxcb,
  libxext,
  libxrender,
  meson,
  pixman,
  zlib,
}:
final:
let
  inherit (tvp.builder.forBase final.base) steps outputs tools;
  command = steps.command { environment = final.environment; };
  paths = [
    "bin"
    "lib"
  ];
in
{
  pname = "cairo";
  inherit
    base
    src
    version
    fontconfig
    freetype
    glib
    libpng
    libx11
    libxcb
    libxext
    libxrender
    meson
    pixman
    zlib
    ;
  inherit (tools) bash coreutils;
  outputs = [ "out" ];
  environment = {
    tools = [
      final.meson
      tools.ninja
      tools.python
    ];
    libraries = with final; [
      fontconfig
      freetype
      glib
      libpng
      libx11
      libxcb
      libxext
      libxrender
      pixman
      zlib
    ];
  };
  runtime.libraries = final.environment.libraries;
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = "xz";
    })
    (steps.shebangs {
      name = "cairo.bind-python";
      paths = [ "version.py" ];
      names = [ "python3" ];
      interpreter = "${tools.python}/bin/python3";
    })
    (command "cairo.configure" ''
      export LDFLAGS="''${LDFLAGS-} -Wl,-rpath,$out/lib"
      meson setup build --prefix="$out" --libdir=lib --buildtype=release --wrap-mode=nodownload \
        -Ddefault_library=shared -Dtests=disabled -Dfontconfig=enabled -Dfreetype=enabled \
        -Dpng=enabled -Dzlib=enabled -Dglib=enabled -Dxlib=enabled -Dxcb=enabled
    '')
    (command "cairo.build" ''ninja -C build -j"$NIX_BUILD_CORES"'')
    (command "cairo.install" ''
      meson install -C build --no-rebuild
      mkdir -p "$out/bin"
    '')
    (steps.split "cairo.finalize")
    (outputs.copyArtifacts { outputs = final.outputs; })
    (outputs.relocateText {
      paths = [
        "lib/pkgconfig"
        "bin"
      ];
    })
    (outputs.shebangs {
      paths = [ "bin" ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${tools.bash}/bin/bash";
    })
    (outputs.strip { inherit paths; })
    (outputs.rpaths {
      inherit paths;
      libraries = final.runtime.libraries;
    })
    (outputs.development { libraries = final.environment.libraries; })
    (outputs.checkPaths { inherit paths; })
  ];
  meta = {
    description = "Cairo vector graphics with image, PNG and X11 backends";
    homepage = "https://www.cairographics.org/";
    license = [
      lib.licenses.lgpl21Only
      lib.licenses.mpl11
    ];
    platforms = [ "x86_64-linux" ];
  };
}

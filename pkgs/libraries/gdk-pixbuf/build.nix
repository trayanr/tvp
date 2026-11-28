{
  tvp,
  lib,
  base,
  src,
  version,
  glib,
  jpeg,
  libpng,
  libtiff,
  meson,
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
  pname = "gdk-pixbuf";
  inherit
    base
    src
    version
    glib
    jpeg
    libpng
    libtiff
    meson
    ;
  inherit (tools) bash coreutils;
  outputs = [ "out" ];
  environment = {
    tools = [
      final.meson
      tools.ninja
      tools.python
      final.glib
    ];
    libraries = with final; [
      glib
      jpeg
      libpng
      libtiff
    ];
  };
  runtime.libraries = final.environment.libraries;
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = "xz";
    })
    (command "gdk-pixbuf.configure" ''
      export LDFLAGS="''${LDFLAGS-} -Wl,-rpath,$out/lib"
      # Keep the standard loaders built in so no mutable loader cache is needed.
      meson setup build --prefix="$out" --libdir=lib --buildtype=release --wrap-mode=nodownload \
        -Ddefault_library=shared -Dbuiltin_loaders=all -Dintrospection=disabled \
        -Dpng=enabled -Djpeg=enabled -Dtiff=enabled -Dgif=enabled -Dgio_sniffing=false \
        -Dman=false -Dtests=false -Dinstalled_tests=false
    '')
    (command "gdk-pixbuf.build" ''ninja -C build -j"$NIX_BUILD_CORES"'')
    (command "gdk-pixbuf.install" "meson install -C build --no-rebuild")
    (steps.split "gdk-pixbuf.finalize")
    (outputs.copyArtifacts { outputs = final.outputs; })
    (outputs.relocateText { paths = [ "lib/pkgconfig" ]; })
    (outputs.strip { inherit paths; })
    (outputs.rpaths {
      inherit paths;
      libraries = final.runtime.libraries;
    })
    (outputs.development { libraries = final.environment.libraries; })
    (outputs.checkPaths { inherit paths; })
  ];
  meta = {
    description = "GObject-based image loading and pixel buffers";
    homepage = "https://gitlab.gnome.org/GNOME/gdk-pixbuf";
    license = lib.licenses.lgpl21Plus;
    platforms = [ "x86_64-linux" ];
  };
}

{
  tvp,
  lib,
  base,
  src,
  version,
  cairo,
  fontconfig,
  freetype,
  fribidi,
  glib,
  harfbuzz,
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
  pname = "pango";
  inherit
    base
    src
    version
    cairo
    fontconfig
    freetype
    fribidi
    glib
    harfbuzz
    meson
    ;
  inherit (tools) bash coreutils;
  outputs = [ "out" ];
  environment = {
    tools = [
      final.meson
      tools.ninja
      glib
      tools.python
    ];
    libraries = with final; [
      cairo
      fontconfig
      freetype
      fribidi
      glib
      harfbuzz
    ];
  };
  runtime.libraries = final.environment.libraries;
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = "xz";
    })
    (command "pango.configure" ''
      export LDFLAGS="''${LDFLAGS-} -Wl,-rpath,$out/lib"
      meson setup build --prefix="$out" --libdir=lib --buildtype=release --wrap-mode=nodownload \
        -Ddefault_library=shared -Dintrospection=disabled -Dbuild-testsuite=false \
        -Dbuild-examples=false -Dfontconfig=enabled -Dfreetype=enabled -Dcairo=enabled
    '')
    (command "pango.build" ''ninja -C build -j"$NIX_BUILD_CORES"'')
    (command "pango.install" "meson install -C build --no-rebuild")
    (steps.split "pango.finalize")
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
    description = "Text layout and rendering library";
    homepage = "https://www.pango.org/";
    license = lib.licenses.lgpl21Plus;
    platforms = [ "x86_64-linux" ];
  };
}

{
  tvp,
  lib,
  base,
  src,
  version,
  meson,
}:
final:
let
  inherit (tvp.builder.forBase final.base) steps outputs tools;
  command = steps.command { environment = final.environment; };
in
{
  pname = "pixman";
  inherit
    base
    src
    version
    meson
    ;
  inherit (tools) bash coreutils;
  outputs = [ "out" ];
  environment.tools = [
    final.meson
    tools.ninja
  ];
  runtime.libraries = [ ];
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = "xz";
    })
    (command "pixman.configure" ''
      meson setup build --prefix="$out" --libdir=lib --buildtype=release --wrap-mode=nodownload \
        -Ddefault_library=shared -Dtests=disabled -Ddemos=disabled -Dgtk=disabled
    '')
    (command "pixman.build" ''ninja -C build -j"$NIX_BUILD_CORES"'')
    (command "pixman.install" "meson install -C build --no-rebuild")
    (steps.split "pixman.finalize")
    (outputs.copyArtifacts { outputs = final.outputs; })
    (outputs.relocateText { paths = [ "lib/pkgconfig" ]; })
    (outputs.strip { paths = [ "lib" ]; })
    (outputs.rpaths {
      paths = [ "lib" ];
      libraries = final.runtime.libraries;
    })
    (outputs.checkPaths { paths = [ "lib" ]; })
  ];
  meta = {
    description = "Low-level pixel manipulation and compositing library";
    homepage = "https://www.pixman.org/";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
}

{
  tvp,
  lib,
  base,
  src,
  version,
  freetype,
  glib,
  icu,
  meson,
}:
final:
let
  inherit (tvp.builder.forBase final.base) steps outputs tools;
  native = import ../../../lib/native-steps.nix { inherit lib; };
  paths = [
    "bin"
    "lib"
  ];
in
{
  pname = "harfbuzz";
  inherit
    base
    src
    version
    freetype
    glib
    icu
    meson
    ;
  inherit (tools) bash coreutils;
  outputs = [ "out" ];
  environment.libraries = [
    final.freetype
    final.glib
    final.icu
  ]
  ++ final.freetype.specification.runtime.libraries
  ++ final.glib.specification.runtime.libraries;
  runtime.libraries = final.environment.libraries;
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = "xz";
    })
    (native.meson {
      name = "harfbuzz";
      inherit (final) meson;
      inherit (tools) ninja pkg-config;
      inherit (final.environment) libraries;
      mesonFlags = [
        "-Ddefault_library=shared"
        "-Dglib=enabled"
        "-Dgobject=enabled"
        "-Dfreetype=enabled"
        "-Dicu=enabled"
        "-Dcairo=disabled"
        "-Dchafa=disabled"
        "-Ddocs=disabled"
        "-Dintrospection=disabled"
        "-Dtests=disabled"
      ];
      doCheck = false;
    })
    (steps.split "harfbuzz.finalize")
    (outputs.copyArtifacts { outputs = final.outputs; })
    (outputs.relocateText {
      paths = [
        "lib/pkgconfig"
        "lib/cmake/harfbuzz"
      ];
    })
    (outputs.strip { inherit paths; })
    (outputs.rpaths {
      inherit paths;
      libraries = final.runtime.libraries;
    })
    {
      name = "harfbuzz.bind-self-libraries";
      tools = [
        tools.binutils
        tools.patchelf
        tools.python
      ];
      run = ''${tools.python}/bin/python3 -B ${../../../lib/append-self-rpaths.py} "$out" ${
        lib.escapeShellArg (
          builtins.toJSON {
            inherit paths;
            directories = [ "lib" ];
            readelf = "${tools.binutils}/bin/readelf";
            patchelf = "${tools.patchelf}/bin/patchelf";
          }
        )
      } ${../../../lib/native-output}'';
    }
    (outputs.checkPaths { inherit paths; })
  ];
  meta = {
    description = "OpenType text shaping library and Unicode integrations";
    homepage = "https://harfbuzz.github.io/";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
}

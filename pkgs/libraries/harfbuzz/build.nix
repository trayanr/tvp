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
  command = steps.command { environment = final.environment; };
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
  environment = {
    tools = [
      final.glib
      final.meson
      tools.ninja
      tools.pkg-config
    ];
    libraries = [
      final.freetype
      final.glib
      final.icu
    ]
    ++ final.freetype.specification.runtime.libraries
    ++ final.glib.specification.runtime.libraries;
    overrides.values = {
      NINJA = "${tools.ninja}/bin/ninja";
      PKG_CONFIG = "${tools.pkg-config}/bin/pkg-config";
    };
  };
  runtime.libraries = final.environment.libraries;
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = "xz";
    })
    (steps.shebangs {
      name = "harfbuzz.generator-shebangs";
      paths = [
        "src/fix_get_types.py"
        "src/gen-def.py"
        "src/gen-harfbuzzcc.py"
        "src/gen-hb-version.py"
      ];
      names = [ "python3" ];
      interpreter = "${tools.python}/bin/python3";
    })
    (command "harfbuzz.configure" ''
      meson setup build . --prefix="$out" --libdir=lib --buildtype=release --wrap-mode=nodownload \
        -Dauto_features=enabled -Ddefault_library=shared \
        -Dglib=enabled -Dgobject=enabled -Dfreetype=enabled -Dicu=enabled \
        -Dcairo=disabled -Dchafa=disabled -Ddocs=disabled -Dintrospection=disabled -Dtests=disabled
    '')
    (command "harfbuzz.build" ''meson compile -C build -j "$NIX_BUILD_CORES"'')
    (command "harfbuzz.install" "meson install -C build --no-rebuild")
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

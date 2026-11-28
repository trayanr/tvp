{
  tvp,
  lib,
  base,
  src,
  version,
  gettext,
  libffi,
  meson,
  ninja,
  pcre2,
  python,
  zlib,
}:
final:
let
  inherit (tvp.builder.forBase final.base) steps outputs tools;
  command = steps.command { environment = final.environment; };
  elfPaths = [
    "bin"
    "lib"
    "libexec"
  ];
  mesonCommand = "${final.meson}/bin/meson";
in
{
  pname = "glib";
  # GIO's installed module and helper locations are compiled into its ELF data.
  artifactName = "${final.pname}-${final.version}";
  inherit
    base
    src
    version
    gettext
    libffi
    meson
    ninja
    pcre2
    python
    zlib
    ;
  inherit (tools) bash coreutils;
  outputs = [ "out" ];
  environment = {
    tools = [
      final.python
      final.meson
      final.ninja
      final.gettext
    ];
    libraries = [
      final.libffi
      final.pcre2
      final.zlib
    ];
  };
  runtime.libraries = final.environment.libraries;
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = "xz";
    })
    (steps.shebangs {
      name = "glib.visibility-generator-shebang";
      paths = [ "tools/gen-visibility-macros.py" ];
      names = [ "python3" ];
      interpreter = "${final.python}/bin/python3";
    })
    (command "glib.configure" ''
      export NINJA=${final.ninja}/bin/ninja
      ${mesonCommand} setup build . --prefix="$out" --libdir=lib --libexecdir=libexec \
        --buildtype=release --default-library=shared --wrap-mode=nodownload \
        -Dauto_features=disabled -Dnls=enabled -Dintrospection=disabled \
        -Dlibmount=disabled -Dlibelf=disabled -Dselinux=disabled -Dsysprof=disabled \
        -Ddocumentation=false -Dman-pages=disabled -Dtests=false
    '')
    (command "glib.build" ''${mesonCommand} compile -C build -j "$NIX_BUILD_CORES"'')
    (command "glib.install" "${mesonCommand} install -C build --no-rebuild")
    (steps.split "glib.finalize")
    (outputs.copyArtifacts { outputs = final.outputs; })
    {
      name = "glib.relocate";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${../jdk-support-relocate.py} "$out" "$TVP_ARTIFACT_ROOT"'';
    }
    (outputs.shebangs {
      paths = [ "bin" ];
      names = [
        "python"
        "python3"
      ];
      interpreter = "${final.python}/bin/python3";
    })
    (
      (outputs.shebangs {
        paths = [ "bin" ];
        names = [
          "bash"
          "sh"
        ];
        interpreter = "${tools.bash}/bin/bash";
      })
      // {
        name = "output.shell-shebangs";
      }
    )
    (outputs.strip { paths = elfPaths; })
    (outputs.rpaths {
      paths = elfPaths;
      libraries = final.runtime.libraries;
    })
    {
      name = "glib.self-runtime";
      tools = [
        tools.binutils
        tools.patchelf
        tools.python
      ];
      run = ''${tools.python}/bin/python3 -B ${../../../lib/append-self-rpaths.py} "$out" ${
        lib.escapeShellArg (
          builtins.toJSON {
            paths = elfPaths;
            directories = [ "lib" ];
            readelf = "${tools.binutils}/bin/readelf";
            patchelf = "${tools.patchelf}/bin/patchelf";
          }
        )
      } ${../../../lib/native-output}'';
    }
    (outputs.development { libraries = final.environment.libraries; })
    (outputs.checkPaths { paths = elfPaths; })
  ];
  meta = {
    description = "Low-level utility, object and I/O libraries for applications";
    homepage = "https://docs.gtk.org/glib/";
    license = lib.licenses.lgpl21Plus;
    platforms = [ "x86_64-linux" ];
  };
}

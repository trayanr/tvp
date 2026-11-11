# Ordinary 1.11.1–1.12.0: compressed neutral zipapp, then runtime binding.
# Suffix adds only an interpreter line; ZIP member bytes are never recompressed.
{
  tvp,
  lib,
  base,
  src,
  version,
  bash,
  coreutils,
  python,
  helperPython,
  ninja,
  cmake,
  pkg-config,
  gnutar,
  gzip,
  findutils,
  patch,
  patches,
}:
final:
let
  inherit (tvp.builder) steps outputs;
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      inherit name run;
      cwd = "source";
    };
  finalCommand = name: run: (command name run) // { cwd = "."; };
in
{
  pname = "meson";
  inherit
    base
    src
    version
    bash
    coreutils
    ;
  inherit
    helperPython
    gnutar
    gzip
    findutils
    patch
    ;
  inherit
    python
    ninja
    cmake
    pkg-config
    patches
    ;
  dependencyProviders = {
    bash = final.runtime.shell;
    inherit (final.runtime)
      python
      ninja
      cmake
      pkg-config
      ;
  };
  environment = {
    tools = [
      final.helperPython
      final.patch
      final.findutils
    ];
    libraries = [ ];
  };
  runtime = {
    shell = final.bash;
    inherit (final)
      python
      ninja
      cmake
      pkg-config
      ;
  };
  buildEnvironment =
    context:
    let
      pc = (import ../../../../lib/pkg-config-environment.nix) (
        context // { tool = final.runtime.pkg-config; }
      );
      cm = final.runtime.cmake.buildEnvironment (context // { tool = final.runtime.cmake; });
    in
    {
      # These providers have disjoint keys. Preserve contribution kinds; global
      # conflicting scalars remain errors. Rebind Meson with .override when
      # selecting a different pkgConfig provider alongside it.
      values = (pc.values or { }) // (cm.values or { });
      paths = (pc.paths or { }) // (cm.paths or { });
      flags = (pc.flags or { }) // (cm.flags or { });
    };
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = final.gnutar;
      gzip = final.gzip;
      findutils = final.findutils;
      compression = "gzip";
    })
    (command "meson.prepare" ''
      ${lib.concatMapStringsSep "\n" (
        p: ''${final.patch}/bin/patch --batch --fuzz=0 -p1 < ${p}''
      ) final.patches}
      ${final.helperPython}/bin/python3 -B - <<'PYTHON'
      from pathlib import Path
      p = Path('mesonbuild/scripts/depfixer.py')
      text = p.read_text(); assert '@TVP_STORE_DIR@' in text
      p.write_text(text.replace('@TVP_STORE_DIR@', '${builtins.storeDir}'))
      PYTHON
    '')
    (command "meson.build" ''
      ${final.helperPython}/bin/python3 packaging/create_zipapp.py . --outfile meson.pyz \
        --interpreter "" --compress
    '')
    (command "meson.install" ''
      ${final.helperPython}/bin/python3 meson.pyz --version
      install -Dm644 meson.pyz "$out/libexec/meson.pyz"
      install -Dm644 ${../setup-hook.sh} "$out/nix-support/setup-hook"
      install -Dm644 man/meson.1 "$out/share/man/man1/meson.1"
    '')
    (steps.split "meson.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    (finalCommand "meson.zipapp-interpreter" ''
      mkdir "$out/bin"
      ${final.gzip}/bin/gzip -n -9 "$out/share/man/man1/meson.1"
      ${final.helperPython}/bin/python3 -B ${../owned/bind-zipapp.py} "$out" ${lib.escapeShellArg "${final.runtime.python}/bin/python3"}
    '')
    (outputs.template {
      python = final.helperPython;
      path = "bin/meson";
      template = ../meson.sh;
      values = {
        bash = "${final.runtime.shell}/bin/bash";
        python = "${final.runtime.python}/bin/python3";
        ninja = "${final.runtime.ninja}/bin/ninja";
        cmake = "${final.runtime.cmake}/bin/cmake";
        pkgConfig = "${final.runtime.pkg-config}/bin/pkg-config";
        out = "@OUTPUT@";
      };
    })
    (finalCommand "meson.launcher-mode" ''chmod 755 "$out/bin/meson"'')
  ];
  meta = {
    homepage = "https://mesonbuild.com/";
    description = "Meson build system with owned Python and Ninja";
    mainProgram = "meson";
    platforms = [ "x86_64-linux" ];
    license = lib.licenses.asl20;
  };
}

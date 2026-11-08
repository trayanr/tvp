# Native ordinary 1.12.1: compressed zipapp, full Python and explicit discovery.
# Launcher and zipapp paths are finalized together; runtime edits reconstruct both.
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
  inherit (tvp.builder) steps;
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      inherit name run;
      cwd = "source";
    };
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
  environment = {
    tools = [
      python
      patch
      findutils
    ];
    libraries = [ ];
  };
  runtime = {
    shell = bash;
    inherit
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
      tar = gnutar;
      inherit gzip findutils;
      compression = "gzip";
    })
    (command "meson.prepare" ''
      ${lib.concatMapStringsSep "\n" (p: ''${patch}/bin/patch --batch --fuzz=0 -p1 < ${p}'') patches}
      ${helperPython}/bin/python3 -B - <<'PYTHON'
      from pathlib import Path
      p = Path('mesonbuild/scripts/depfixer.py')
      text = p.read_text(); assert '@TVP_STORE_DIR@' in text
      p.write_text(text.replace('@TVP_STORE_DIR@', '${builtins.storeDir}'))
      PYTHON
    '')
    (command "meson.build" ''
      ${final.runtime.python}/bin/python3 packaging/create_zipapp.py . --outfile meson.pyz \
        --interpreter ${final.runtime.python}/bin/python3 --compress
    '')
    (command "meson.install" ''
      install -Dm755 meson.pyz "$out/libexec/meson.pyz"
      install -Dm644 ${../setup-hook.sh} "$out/nix-support/setup-hook"
      install -Dm644 man/meson.1 "$out/share/man/man1/meson.1"
      ${gzip}/bin/gzip -n -9 "$out/share/man/man1/meson.1"
      ${helperPython}/bin/python3 -B - "$out" <<'PYTHON'
      from pathlib import Path
      import sys
      out = sys.argv[1]
      text = Path('${../meson.sh}').read_text()
      for key, value in {'bash':'${final.runtime.shell}/bin/bash', 'python':'${final.runtime.python}/bin/python3',
                        'ninja':'${final.runtime.ninja}/bin/ninja', 'cmake':'${final.runtime.cmake}/bin/cmake',
                        'pkgConfig':'${final.runtime.pkg-config}/bin/pkg-config', 'out':out}.items():
          assert '@' + key + '@' in text
          text = text.replace('@' + key + '@', value)
      p = Path(out) / 'bin/meson'; p.parent.mkdir(); p.write_text(text); p.chmod(0o755)
      PYTHON
    '')
  ];
  meta = {
    description = "Meson compressed zipapp with owned native tools";
    mainProgram = "meson";
    platforms = [ "x86_64-linux" ];
    license = "Apache-2.0";
  };
}

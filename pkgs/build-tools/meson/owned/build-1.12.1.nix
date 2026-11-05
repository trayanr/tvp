# Compressed zipapp with coherent normal recipe input overrides and explicit discovery.
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
  pkgConfig,
  gnutar,
  gzip,
  findutils,
  patch,
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
  buildEnvironment =
    context:
    let
      pc = (import ../../../../lib/pkg-config-environment.nix) (context // { tool = pkgConfig; });
      cm = cmake.buildEnvironment (context // { tool = cmake; });
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
      ${patch}/bin/patch -p1 < ${../patches/store-rpaths.patch}
      ${helperPython}/bin/python3 -B - <<'PYTHON'
      from pathlib import Path
      p = Path('mesonbuild/scripts/depfixer.py')
      text = p.read_text(); assert '@TVP_STORE_DIR@' in text
      p.write_text(text.replace('@TVP_STORE_DIR@', '${builtins.storeDir}'))
      PYTHON
    '')
    (command "meson.build" ''
      ${python}/bin/python3 packaging/create_zipapp.py . --outfile meson.pyz \
        --interpreter ${python}/bin/python3 --compress
    '')
    (command "meson.install" ''
      install -Dm755 meson.pyz "$out/libexec/meson.pyz"
      install -Dm644 man/meson.1 "$out/share/man/man1/meson.1"
      ${helperPython}/bin/python3 -B - "$out" <<'PYTHON'
      from pathlib import Path
      import sys
      out = sys.argv[1]
      text = Path('${../meson.sh}').read_text()
      for key, value in {'bash':'${bash}/bin/bash', 'python':'${python}/bin/python3',
                        'ninja':'${ninja}/bin/ninja', 'cmake':'${cmake}/bin/cmake',
                        'pkgConfig':'${pkgConfig}/bin/pkg-config', 'out':out}.items():
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

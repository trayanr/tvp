# Existing BUILD-tool profile on the owned native base; prefix-sensitive, single stage.
{
  tvp,
  lib,
  base,
  src,
  version,
  bash,
  coreutils,
  python,
  gnumake,
  gnutar,
  gzip,
  findutils,
  patch,
  sed,
  grep,
  gawk,
  diffutils,
  pkgConfig,
  openssl,
  zlib,
  bzip2,
  xz,
  binutils,
  patchelf,
}:
final:
let
  inherit (tvp.builder) steps outputs;
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      inherit name;
      cwd = "source";
      run = ''
        mkdir -p "$evidence"
        status=0
        ${bash}/bin/bash -euc ${lib.escapeShellArg run} > "$evidence/${name}.log" 2>&1 || status=$?
        printf '%s\n' "$status" > "$evidence/${name}.status"
        if (( status )); then cat "$evidence/${name}.log"; exit "$status"; fi
      '';
    };
  disabled = [
    "_crypt"
    "_ctypes"
    "_curses"
    "_curses_panel"
    "_dbm"
    "_gdbm"
    "_sqlite3"
    "_tkinter"
    "_uuid"
    "nis"
    "readline"
  ];
in
{
  pname = "python-build";
  inherit
    base
    src
    version
    bash
    coreutils
    ;
  outputs = [
    "out"
    "evidence"
  ];
  environment = {
    tools = [
      gnumake
      findutils
      patch
      sed
      grep
      gawk
      diffutils
      pkgConfig
    ];
    libraries = [
      openssl
      zlib
      bzip2
      xz
    ];
  };
  runtime.libraries = (final.base.environment final.environment).libraries;
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = gnutar;
      inherit xz findutils;
      compression = "xz";
    })
    (command "python.prepare" ''
      ${patch}/bin/patch -p1 < ${../patches/subprocess-shell.patch}
      ${python}/bin/python3 -B - <<'PYTHON'
      from pathlib import Path
      shell = '${bash}/bin/bash'
      p = Path('Lib/subprocess.py')
      text = p.read_text(); assert '@TVP_SHELL@' in text
      p.write_text(text.replace('@TVP_SHELL@', shell))
      p = Path('Makefile.pre.in')
      text = p.read_text(); assert 'SHELL=\t\t/bin/sh -e' in text
      p.write_text(text.replace('SHELL=\t\t/bin/sh -e', 'SHELL= ' + shell + ' -e'))
      p = Path('Misc/python-config.sh.in'); text = p.read_text()
      text = text.replace('#!/bin/sh', '#!' + shell)
      text = text.replace('dirname ', '${coreutils}/bin/dirname ')
      text = text.replace('which readlink', 'command -v ${coreutils}/bin/readlink')
      text = text.replace('readlink -f', '${coreutils}/bin/readlink -f')
      text = text.replace('| sed ', '| ${sed}/bin/sed ')
      p.write_text(text)
      PYTHON
      printf '%s\n' '*disabled*' ${lib.escapeShellArgs disabled} > Modules/Setup.local
    '')
    (command "python.configure" ''
      export CONFIG_SHELL=${bash}/bin/bash
      ${bash}/bin/bash ./configure --prefix="$out" \
        --without-ensurepip --without-readline --disable-test-modules --with-platlibdir=lib \
        --with-openssl=${openssl} --with-openssl-rpath=auto
      cp config.log "$evidence/config.log"
    '')
    (command "python.build" ''
      ${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${bash}/bin/bash
      # CPython can remove a failed extension while returning build success.
      ./python -c 'import _ssl, _hashlib, zlib, _bz2, _lzma'
    '')
    (command "python.install" ''
      ${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${bash}/bin/bash "COMPILEALL_OPTS=-j$NIX_BUILD_CORES" install
      mkdir -p "$out/share/licenses/python"
      cp LICENSE "$out/share/licenses/python/"
      ${python}/bin/python3 -B - "$out" <<'PYTHON'
      from pathlib import Path
      import sys
      root = Path(sys.argv[1])
      for p in root.rglob('*'):
          if not p.is_file() or p.is_symlink(): continue
          if p.suffix == '.py' or p.name in ['idle3.12', 'pydoc3.12']:
              data = p.read_bytes()
              if data.startswith(b'#!'):
                  p.write_bytes(b'#!' + str(root).encode() + b'/bin/python3\n' + data.split(b'\n', 1)[1])
      # Linux development helpers, retained with declared shell and utilities.
      for name in ['install-sh', 'makesetup']:
          for p in (root / 'lib/python3.12').glob('config-*/' + name):
              text = p.read_text().split('\n', 1)[1]
              p.write_text('#!${bash}/bin/bash\nexport PATH=${
                lib.concatStringsSep ":" (
                  map (p: "${p}/bin") [
                    bash
                    coreutils
                    sed
                    grep
                    diffutils
                    binutils
                  ]
                )
              }\n' + text)
      # This vendored macOS download maintenance utility is outside this profile.
      (root / 'lib/python3.12/ctypes/macholib/fetch_macholib').unlink()
      PYTHON
    '')
    # CPython installs extensions read-only. Restore their exact modes after each
    # selected ELF transform, rather than omitting them from finalization.
    (
      let
        r = outputs.rpaths {
          inherit python binutils patchelf;
          base = final.base;
          paths = [
            "bin"
            "lib"
          ];
          elfKinds = [ "runtime" ];
          libraries = final.runtime.libraries;
        };
      in
      r
      // {
        run = ''
          ${python}/bin/python3 -B ${./finalize.py} "$out" ${lib.escapeShellArg r.run} ${bash}/bin/bash
        '';
      }
    )
  ];
  passthru = {
    disabledModules = disabled;
  };
  meta = {
    description = "CPython BUILD tools with TLS and archive support";
    mainProgram = "python3";
    platforms = [ "x86_64-linux" ];
    license = "Python-2.0";
  };
}

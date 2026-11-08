# Ordinary native 3.15.2 starts the source-owned general-purpose boundary.
# External mpdecimal, all existing stdlib/test modules, static embedding and
# offline ensurepip are required here. Earlier and BUILD profiles stay separate.
# Prefix-sensitive sysconfig, bytecode and pip installation use one real stage;
# runtime edits therefore reconstruct and recompile this procedure.
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
  findutils,
  patch,
  sed,
  grep,
  gawk,
  diffutils,
  pkgConfig,
  binutils,
  patchelf,
  runtimeBash,
  openssl,
  zlib,
  bzip2,
  xz,
  zstd,
  mpdecimal,
  libffi,
  sqlite,
  gdbm,
  readline,
  ncurses,
  disabledModules,
  patches,
  linkUnwinder ? true,
  finalizeEx ? true,
  embedFlag ? true,
  textSubprocess ? true,
  upstreamModules ? [
    "test_ssl"
    "test_hashlib"
    "test_ctypes"
    "test_sqlite3"
    "test_dbm_gnu"
    "test_dbm_ndbm"
    "test_bz2"
    "test_lzma"
    "test_zlib"
    "test_readline"
  ],
}:
final:
let
  inherit (tvp.builder) steps outputs;
  environment = final.base.environment final.environment;
  # Convert structured native environment contributions to explicit compiler
  # arguments recorded by configure and published to installed consumers. No
  # inherited setup-hook flags participate in the target build.
  compileFlags = environment.environmentContributions.NIX_CFLAGS_COMPILE.value ++ [
    "-I${lib.getDev ncurses}/include/ncursesw"
  ];
  linkFlags =
    environment.environmentContributions.NIX_LDFLAGS.value
    ++ lib.optionals linkUnwinder [
      "--no-as-needed"
      "-lgcc_s"
      "--as-needed"
    ];
  command =
    name: run:
    environment
    // {
      name = "python.${name}";
      cwd = "source";
      env = environment.env // {
        NIX_CFLAGS_COMPILE = "";
        NIX_LDFLAGS = "";
        CPPFLAGS = environment.env.CPPFLAGS or (lib.concatStringsSep " " compileFlags);
        LDFLAGS = environment.env.LDFLAGS or (lib.concatMapStringsSep " " (f: "-Wl,${f}") linkFlags);
      };
      inherit run;
    };
  make = ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'';
  mutableOutput =
    record:
    record
    // {
      run = ''${python}/bin/python3 -B ${./finalize.py} "$out" ${lib.escapeShellArg record.run} ${final.bash}/bin/bash'';
    };
in
{
  pname = "python";
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
      zstd
      mpdecimal
      libffi
      sqlite
      gdbm
      readline
      ncurses
    ];
  };
  runtime = {
    libraries = environment.libraries;
    shell = runtimeBash;
  };
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = gnutar;
      inherit xz findutils;
      compression = "xz";
    })
    (command "prepare" ''
      ${lib.concatMapStringsSep "\n" (p: ''${patch}/bin/patch --batch --fuzz=0 -p1 < ${p}'') patches}
      ${python}/bin/python3 -B ${./prepare.py} \
        ${lib.escapeShellArg "${final.runtime.shell}/bin/bash"} \
        ${lib.escapeShellArg "${final.bash}/bin/bash"} \
        ${lib.escapeShellArg "${final.coreutils}/bin"} ${lib.escapeShellArg "${sed}/bin/sed"}
      printf '%s\n' '*disabled*' ${lib.escapeShellArgs disabledModules} > Modules/Setup.local
    '')
    (command "configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash
      ${final.bash}/bin/bash ./configure --prefix="$out" \
        --with-system-libmpdec --with-ensurepip=install --with-pkg-config=yes \
        --with-dbmliborder=gdbm --with-platlibdir=lib \
        --with-openssl=${openssl} --with-openssl-rpath=auto
      # Raw configure evidence belongs in the private build log, never installed.
      printf '\nTVP_CONFIG_LOG_BEGIN\n' >&2
      cat config.log >&2
      printf '\nTVP_CONFIG_LOG_END\n' >&2
    '')
    (command "build" ''
      ${make}
      ./python -E -c 'import _ssl, _hashlib, zlib, _bz2, _lzma, _zstd, _decimal, _ctypes, _sqlite3, _gdbm, _dbm, readline, _curses, _curses_panel'
    '')
    (command "install" ''
      ${make} "COMPILEALL_OPTS=-j$NIX_BUILD_CORES" install
      ${python}/bin/python3 -B ${./install.py} "$out" ${final.bash}/bin/bash \
        ${
          lib.escapeShellArg (
            lib.makeBinPath [
              final.bash
              final.coreutils
              sed
              grep
              diffutils
              binutils
            ]
          )
        }
      mkdir -p "$out/share/licenses/python"
      cp LICENSE "$out/share/licenses/python/"
    '')
    (mutableOutput (
      outputs.rpaths {
        inherit python binutils patchelf;
        base = final.base;
        paths = [
          "bin"
          "lib"
        ];
        elfKinds = [ "runtime" ];
        libraries = final.runtime.libraries;
        dlopenDirectories = final.runtime.dlopenDirectories or [ ];
      }
    ))
    (outputs.development {
      inherit python;
      libraries = [ ];
    })
    (command "receipt" ''
      "$out/bin/python3" -I - <<'PYTHON'
      import json, sysconfig, pathlib
      p = pathlib.Path(sysconfig.get_config_var('prefix'))
      receipt = {k: v for k, v in sysconfig.get_config_vars().items()
                 if (k.startswith('MODULE_') and k.endswith('_STATE')) or
                 k in ['PY_ENABLE_SHARED', 'PY_SQLITE_ENABLE_LOAD_EXTENSION',
                       'PY_SQLITE_HAVE_SERIALIZE', 'SOABI', 'EXT_SUFFIX']}
      (p / 'share/python').mkdir(parents=True)
      (p / 'share/python/features.json').write_text(json.dumps(receipt, indent=2, sort_keys=True) + '\n')
      PYTHON
    '')
  ];
  tvp = {
    profile = "general-purpose";
    features = {
      externalModules = true;
      tls = true;
      archiveCompression = true;
      pipInstalled = true;
      inherit
        finalizeEx
        embedFlag
        textSubprocess
        linkUnwinder
        ;
    };
    inherit disabledModules upstreamModules;
  };
  meta = {
    description = "General-purpose CPython interpreter with native extension and virtual environment support";
    homepage = "https://www.python.org/";
    license = lib.licenses.psfl;
    platforms = [ "x86_64-linux" ];
    mainProgram = "python3";
  };
}

# 3.7–3.11: Setup.local exclusions; setup.py detects extensions.
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
  helperGrep,
  binutils,
  patchelf,
  runtimeBash,
  openssl,
  zlib,
  bzip2,
  xz,
  libffi,
  sqlite,
  gdbm,
  readline,
  ncurses,
  libxcrypt,
  disabledModules,
  patches,
  linkUnwinder ? true,
  pkgConfigRequired ? false,
  opensslRpath ? true,
  systemFfi ? false,
  opensslPrefix ? true,
  platlibdir ? true,
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
  compileFlags =
    environment.environmentContributions.NIX_CFLAGS_COMPILE.value
    ++ (map (dep: "-I${lib.getDev dep}/include") (builtins.attrValues final.libraries))
    ++ [
      "-I${lib.getDev final.libraries.ncurses}/include/ncursesw"
    ];
  linkFlags =
    environment.environmentContributions.NIX_LDFLAGS.value
    ++ lib.optionals final.linkUnwinder [
      "--no-as-needed"
      "-lgcc_s"
      "--as-needed"
    ];
  command =
    name: run:
    environment
    // {
      name = "python.${name}";
      env = environment.env // {
        NIX_CFLAGS_COMPILE = "";
        NIX_LDFLAGS = "";
        CPPFLAGS = environment.env.CPPFLAGS or (lib.concatStringsSep " " compileFlags);
        LDFLAGS =
          environment.env.LDFLAGS
            or (lib.concatMapStringsSep " " (f: if lib.hasPrefix "-L" f then f else "-Wl,${f}") linkFlags);
      };
      inherit run;
    };
  sourceCommand = name: run: (command name run) // { cwd = "source"; };
  make = ''${final.tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'';
  mutableOutput =
    record:
    record
    // {
      run = ''${final.tools.python}/bin/python3 -B ${./finalize.py} "$out" ${lib.escapeShellArg record.run} ${final.bash}/bin/bash'';
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
  artifactName = "${final.pname}-${final.version}";
  inherit
    disabledModules
    patches
    linkUnwinder
    finalizeEx
    embedFlag
    textSubprocess
    upstreamModules
    ;
  inherit
    pkgConfigRequired
    opensslRpath
    systemFfi
    opensslPrefix
    platlibdir
    ;
  tools = {
    inherit
      python
      gnumake
      gnutar
      findutils
      patch
      sed
      grep
      gawk
      diffutils
      pkgConfig
      helperGrep
      binutils
      patchelf
      ;
  };
  libraries = {
    inherit
      openssl
      zlib
      bzip2
      xz
      libffi
      sqlite
      gdbm
      readline
      ncurses
      libxcrypt
      ;
  };
  dependencyProviders =
    final.tools // final.runtime.providers // { runtimeBash = final.runtime.shell; };
  environment = {
    overrides.values.LIBS =
      "-lm"
      + " -L${lib.getLib final.libraries.libxcrypt}/lib -Wl,-rpath,${lib.getLib final.libraries.libxcrypt}/lib";
    tools = map (name: final.tools.${name}) [
      "python"
      "gnumake"
      "findutils"
      "patch"
      "sed"
      "grep"
      "gawk"
      "diffutils"
      "pkgConfig"
    ];
    libraries = builtins.attrValues final.libraries;
  };
  runtime = {
    providers = final.libraries;
    libraries = builtins.attrValues final.runtime.providers;
    shell = runtimeBash;
  };
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = final.tools.gnutar;
      xz = final.libraries.xz;
      findutils = final.tools.findutils;
      compression = "xz";
    })
    (steps.prepareAutotools {
      name = "python.autotools";
      bash = final.bash;
      python = final.tools.python;
      base = final.base;
    })
    (sourceCommand "prepare" ''
      ${lib.concatMapStringsSep "\n" (
        p: ''${final.tools.patch}/bin/patch --batch --fuzz=0 -p1 < ${p}''
      ) final.patches}
      ${final.tools.python}/bin/python3 -B ${./prepare.py} \
        ${lib.escapeShellArg "${final.bash}/bin/bash"} \
        ${lib.escapeShellArg "${final.bash}/bin/bash"} \
        ${lib.escapeShellArg "${final.coreutils}/bin"} ${lib.escapeShellArg "${final.tools.sed}/bin/sed"}
      printf '%s\n' '*disabled*' ${lib.escapeShellArgs final.disabledModules} > Modules/Setup.local
    '')
    (sourceCommand "configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash
      ${final.bash}/bin/bash ./configure --prefix="$out" ${lib.escapeShellArgs final.configureFlags}
      # Raw configure evidence belongs in the private build log, never installed.
      printf '\nTVP_CONFIG_LOG_BEGIN\n' >&2
      cat config.log >&2
      printf '\nTVP_CONFIG_LOG_END\n' >&2
    '')
    (sourceCommand "build" ''
      ${make}
    '')
    (sourceCommand "install" ''
      ${make} "COMPILEALL_OPTS=-j$NIX_BUILD_CORES" install
      mkdir -p "$out/share/licenses/python"
      cp LICENSE "$out/share/licenses/python/"
    '')
    (steps.split "python.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    (command "relocate-prefix" ''
      ${final.tools.python}/bin/python3 -B ${./relocate.py} "$out"
      ${final.tools.python}/bin/python3 -B ${./install.py} "$out" ${final.runtime.shell}/bin/bash \
        ${
          lib.escapeShellArg (
            lib.makeBinPath [
              final.runtime.shell
              final.coreutils
              final.tools.sed
              final.tools.helperGrep
              final.tools.binutils
            ]
          )
        } \
        ${lib.escapeShellArg "${final.bash}/bin/bash"} ${lib.escapeShellArg "${final.runtime.shell}/bin/bash"}
    '')
    (mutableOutput (
      outputs.strip {
        inherit (final.tools) python binutils;
        paths = [
          "bin"
          "lib"
        ];
        elfKinds = [ "runtime" ];
      }
    ))
    (outputs.stripArchives {
      inherit (final.tools) python binutils;
      paths = [ "lib" ];
    })
    (mutableOutput (
      outputs.rpaths {
        inherit (final.tools) python binutils patchelf;
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
      inherit (final.tools) python;
      libraries = [ final.runtime.providers.libxcrypt ];
    })
    (outputs.checkPaths {
      inherit (final.tools) python binutils patchelf;
      paths = [
        "bin"
        "lib"
      ];
      elfKinds = [ "runtime" ];
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
  configureFlags =
    [
      "--with-ensurepip=install"
      "--with-dbmliborder=gdbm"
    ]
    ++ lib.optional final.pkgConfigRequired "--with-pkg-config=yes"
    ++ lib.optional final.opensslRpath "--with-openssl-rpath=auto"
    ++ lib.optional final.platlibdir "--with-platlibdir=lib"
    ++ lib.optional final.systemFfi "--with-system-ffi"
    ++ lib.optional final.opensslPrefix "--with-openssl=${final.libraries.openssl}";
  tvp = {
    profile = "general-purpose";
    features = {
      measuredProfile = false;
      externalModules = true;
      tls = true;
      archiveCompression = true;
      pipInstalled = true;
      inherit (final)
        finalizeEx
        embedFlag
        textSubprocess
        linkUnwinder
        ;
    };
    disabledModules = final.disabledModules;
    upstreamModules = final.upstreamModules;
  };
  meta = {
    description = "General-purpose CPython interpreter with native extension and virtual environment support";
    homepage = "https://www.python.org/";
    license = lib.licenses.psfl;
    platforms = [ "x86_64-linux" ];
    mainProgram = "python3";
  };
}

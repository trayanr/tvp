# Complete CPython3.5.10 profile procedure; installed upstream assertions remain independent.
{
  tvp,
  lib,
  base,
  src,
  version,
  runtimeBash,
  pkg-config,
  grep,
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
  patches,
  buildFeatures ? { },
  sourceLayout ? { },
  installedInterface ? { },
  upstreamPolicy ? { },
}:
final:
let
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs tools;
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
    ++ lib.optionals final.buildFeatures.linkUnwinder [
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
  make = ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'';
  mutableOutput =
    record:
    record
    // {
      run = ''${tools.python}/bin/python3 -B ${./native/finalize.py} "$out" ${lib.escapeShellArg record.run} ${final.bash}/bin/bash'';
    };
in
{
  pname = "python";
  inherit
    base
    src
    version
    patches
    pkg-config
    grep
    ;
  inherit (tools) bash coreutils;
  artifactName = "${final.pname}-${final.version}";
  buildFeatures = {
    linkUnwinder = true;
    disabledModules = [
      "_tkinter"
      "_uuid"
      "nis"
    ];
  } // buildFeatures;
  sourceLayout = {
    compression = "xz";
    pkgConfigRequired = false;
    opensslRpath = true;
    systemFfi = false;
    opensslPrefix = true;
    platlibdir = true;
  } // sourceLayout;
  installedInterface = {
    finalizeEx = true;
    embedFlag = true;
    textSubprocess = true;
  } // installedInterface;
  upstreamPolicy = {
    modules = [
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
    ];
  } // upstreamPolicy;
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
    {
      inherit (final) pkg-config grep;
    }
    // final.runtime.providers
    // {
      runtimeBash = final.runtime.shell;
    };
  environment = {
    overrides.values.LIBS =
      "-lm"
      + " -L${lib.getLib final.libraries.libxcrypt}/lib -Wl,-rpath,${lib.getLib final.libraries.libxcrypt}/lib";
    tools = [
      tools.python
      tools.gnumake
      tools.findutils
      tools.patch
      tools.sed
      tools.grep
      tools.gawk
      tools.diffutils
      final.pkg-config
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
      xz = final.libraries.xz;
      compression = final.sourceLayout.compression;
    })
    (steps.prepareAutotools {
      name = "python.autotools";
    })
    (sourceCommand "prepare" ''
      ${lib.concatMapStringsSep "\n" (
        p: "${tools.patch}/bin/patch --batch --fuzz=0 -p1 < ${p}"
      ) final.patches}
      ${tools.python}/bin/python3 -B ${./native/prepare.py} \
        ${lib.escapeShellArg "${final.bash}/bin/bash"} \
        ${lib.escapeShellArg "${final.bash}/bin/bash"} \
        ${lib.escapeShellArg "${final.coreutils}/bin"} ${lib.escapeShellArg "${tools.sed}/bin/sed"}
      : > Modules/Setup.local
      ${tools.python}/bin/python3 -B -c 'from pathlib import Path; import sys; p=Path("setup.py"); s=p.read_text(); assert "@TVP_DISABLED_MODULES@" in s; p.write_text(s.replace("@TVP_DISABLED_MODULES@", sys.argv[1]))' ${lib.escapeShellArg (builtins.toJSON final.buildFeatures.disabledModules)}
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
    (outputs.copyArtifacts { })
    (command "relocate-prefix" ''
      ${tools.python}/bin/python3 -B ${./native/relocate.py} "$out"
      ${tools.python}/bin/python3 -B ${./native/install.py} "$out" ${final.runtime.shell}/bin/bash \
        ${
          lib.escapeShellArg (
            lib.makeBinPath [
              final.runtime.shell
              final.coreutils
              tools.sed
              final.grep
              tools.binutils
            ]
          )
        } \
        ${lib.escapeShellArg "${final.bash}/bin/bash"} ${lib.escapeShellArg "${final.runtime.shell}/bin/bash"}
    '')
    (mutableOutput (
      outputs.strip {
        paths = [
          "bin"
          "lib"
        ];
        elfKinds = [ "runtime" ];
      }
    ))
    (outputs.stripArchives {
      paths = [ "lib" ];
    })
    (mutableOutput (
      outputs.rpaths {
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
      libraries = [ final.runtime.providers.libxcrypt ];
    })
    (outputs.checkPaths {
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
    ++ lib.optional final.sourceLayout.pkgConfigRequired "--with-pkg-config=yes"
    ++ lib.optional final.sourceLayout.opensslRpath "--with-openssl-rpath=auto"
    ++ lib.optional final.sourceLayout.platlibdir "--with-platlibdir=lib"
    ++ lib.optional final.sourceLayout.systemFfi "--with-system-ffi"
    ++ lib.optional final.sourceLayout.opensslPrefix "--with-openssl=${final.libraries.openssl}";
  tvp = {
    profile = "general-purpose";
    features = {
      measuredProfile = false;
      externalModules = true;
      tls = true;
      archiveCompression = true;
      pipInstalled = true;
      finalizeEx = final.installedInterface.finalizeEx;
      embedFlag = final.installedInterface.embedFlag;
      textSubprocess = final.installedInterface.textSubprocess;
      linkUnwinder = final.buildFeatures.linkUnwinder;

    };
    disabledModules = final.buildFeatures.disabledModules;
    upstreamModules = final.upstreamPolicy.modules;
  };
  meta = {
    description = "General-purpose CPython interpreter with native extension and virtual environment support";
    homepage = "https://www.python.org/";
    license = lib.licenses.psfl;
    platforms = [ "x86_64-linux" ];
    mainProgram = "python3";
  };
}

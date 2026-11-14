# Complete public python-build profile; earlier pinned builders stay separate.
{
  tvp,
  lib,
  base,
  src,
  version,
  file,
  xz,
  openssl,
  zlib,
  bzip2,
  pkg-config,
  patches,
  buildFeatures ? { },
}:
final:
let
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs tools;
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      inherit name run;
    };
  sourceCommand = name: run: (command name run) // { cwd = "source"; };
  sourceConfig = builtins.toJSON {
    shell = "${final.bash}/bin/bash";
    coreutils = toString final.coreutils;
    sed = toString tools.sed;
  };
  config = builtins.toJSON {
    shell = "${final.runtime.shell}/bin/bash";
    coreutils = toString final.coreutils;
    sed = toString tools.sed;
    helperPath = lib.makeBinPath [
      final.bash
      final.coreutils
      tools.sed
      tools.grep
      tools.diffutils
      tools.binutils
    ];
  };
  prefix =
    action:
    ''${tools.python}/bin/python3 -B ${./native/prefix.py} "$out" ${lib.escapeShellArg config} ${action}'';
  transform =
    step:
    step
    // {
      run = prefix "transform" + " " + lib.escapeShellArg step.run;
    };
in
{
  pname = "python-build";
  inherit
    base
    src
    version
    patches
    file
    ;
  inherit pkg-config;
  inherit (tools) bash coreutils;
  artifactName = "${final.pname}-${final.version}";
  buildFeatures = {
    disabledModules = [
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
  } // buildFeatures;
  libraries = {
    inherit
      openssl
      zlib
      bzip2
      xz
      ;
  };
  dependencyProviders =
    {
      inherit (final) file pkg-config;
    }
    // {
      inherit (final.runtime)
        openssl
        zlib
        bzip2
        xz
        ;
    };
  environment = {
    tools = [
      tools.gnumake
      tools.findutils
      tools.patch
      tools.sed
      tools.grep
      tools.gawk
      tools.diffutils
      final.file
      final.pkg-config
    ];
    libraries = builtins.attrValues final.libraries;
  };
  runtime = {
    shell = final.bash;
    inherit (final.libraries)
      openssl
      zlib
      bzip2
      xz
      ;
    libraries = [
      final.runtime.openssl
      final.runtime.zlib
      final.runtime.bzip2
      final.runtime.xz
    ];
  };
  development = {
    includeDirectories = [ "include/python3.12" ];
    libraries = [ ];
  };
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      xz = final.libraries.xz;
      compression = "xz";
    })
    (sourceCommand "python.validate-source" ''
      ${tools.python}/bin/python3 -B ${./native/prefix.py} "$PWD" ${lib.escapeShellArg sourceConfig} validate-source
    '')
    (steps.prepareAutotools {
      name = "python.autotools";
    })
    (sourceCommand "python.prepare" ''
      ${lib.concatMapStringsSep "\n" (p: "${tools.patch}/bin/patch -p1 < ${p}") final.patches}
      ${tools.python}/bin/python3 -B ${./native/prefix.py} "$PWD" ${lib.escapeShellArg sourceConfig} prepare
      printf '%s\n' '*disabled*' ${lib.escapeShellArgs final.buildFeatures.disabledModules} > Modules/Setup.local
    '')
    (sourceCommand "python.configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash
      ${final.bash}/bin/bash ./configure --prefix="$out" ${lib.escapeShellArgs final.configureFlags}
    '')
    (sourceCommand "python.build" ''
      ${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash
    '')
    (sourceCommand "python.install" ''
      ${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash "COMPILEALL_OPTS=-j$NIX_BUILD_CORES" install
      mkdir -p "$out/share/licenses/python"
      cp LICENSE "$out/share/licenses/python/"
    '')
    (steps.split "python.finalize")
    (outputs.copyArtifacts { })
    (command "python.relocate-prefix" ''
      ${tools.python}/bin/python3 -B ${../python/native/relocate.py} "$out"
      ${prefix "install"}
      ${tools.python}/bin/python3 -B ${../python/native/install.py} "$out" ${final.runtime.shell}/bin/bash ${
        lib.escapeShellArg (
          lib.makeBinPath [
            final.bash
            final.coreutils
            tools.sed
            tools.grep
            tools.diffutils
            tools.binutils
          ]
        )
      } \
        ${lib.escapeShellArg "${final.bash}/bin/bash"} ${lib.escapeShellArg "${final.runtime.shell}/bin/bash"}
    '')
    (transform (
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
    (transform (
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
      libraries = final.development.libraries;
    })
    (outputs.checkPaths {
      paths = [
        "bin"
        "lib"
      ];
      elfKinds = [ "runtime" ];
    })
  ];
  configureFlags = [
    "--without-ensurepip"
    "--without-readline"
    "--disable-test-modules"
    "--with-platlibdir=lib"
    "--with-openssl=${final.libraries.openssl}"
    "--with-openssl-rpath=auto"
  ];
  tvp = {
    disabledModules = final.buildFeatures.disabledModules;
    profile = "build-tools";
    features = {
      externalModules = true;
      pipInstalled = false;
      tls = true;
      archiveCompression = true;
    };
  };
  meta = {
    description = "CPython build-tools profile on the source-GNU base";
    homepage = "https://www.python.org/";
    license = lib.licenses.psfl;
    platforms = [ "x86_64-linux" ];
    mainProgram = "python3";
  };
}

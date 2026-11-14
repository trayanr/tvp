# Complete public python-minimal profile; earlier pinned builders stay separate.
{
  tvp,
  lib,
  base,
  src,
  version,
  file,
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
  pname = "python-minimal";
  inherit
    base
    src
    version
    patches
    file
    ;
  inherit (tools) bash coreutils;
  artifactName = "${final.pname}-${final.version}";
  buildFeatures = {
    disabledModules = [
      "_bz2"
      "_crypt"
      "_ctypes"
      "_curses"
      "_curses_panel"
      "_dbm"
      "_gdbm"
      "_hashlib"
      "_lzma"
      "_sqlite3"
      "_ssl"
      "_tkinter"
      "_uuid"
      "nis"
      "readline"
      "zlib"
    ];
  } // buildFeatures;
  dependencyProviders = {
    inherit (final) file;
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
    ];
    libraries = [ ];
  };
  runtime = {
    shell = final.bash;
    libraries = [ ];
  };
  development = {
    includeDirectories = [ "include/python3.12" ];
    libraries = [ ];
  };
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
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
  ];
  tvp = {
    disabledModules = final.buildFeatures.disabledModules;
    profile = "build";
    features = {
      externalModules = false;
      pipInstalled = false;
    };
  };
  meta = {
    description = "CPython build profile on the source-GNU base";
    homepage = "https://www.python.org/";
    license = lib.licenses.psfl;
    platforms = [ "x86_64-linux" ];
    mainProgram = "python3";
  };
}

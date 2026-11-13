# 3.12.5: independent public source-GNU CPython build profile, installed-artifact/final split.
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
  xz,
  gzip,
  findutils,
  patch,
  sed,
  grep,
  gawk,
  diffutils,
  file,
  binutils,
  patchelf,
  disabledModules,
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
    };
  sourceCommand = name: run: (command name run) // { cwd = "source"; };
  sourceConfig = builtins.toJSON {
    shell = "${final.bash}/bin/bash";
    coreutils = toString final.coreutils;
    sed = toString final.tools.sed;
  };
  config = builtins.toJSON {
    shell = "${final.runtime.shell}/bin/bash";
    coreutils = toString final.coreutils;
    sed = toString final.tools.sed;
    helperPath = lib.makeBinPath [
      final.bash
      final.coreutils
      final.tools.sed
      final.tools.grep
      final.tools.diffutils
      final.tools.binutils
    ];
  };
  prefix =
    action:
    ''${final.tools.python}/bin/python3 -B ${./prefix.py} "$out" ${lib.escapeShellArg config} ${action}'';
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
    bash
    coreutils
    disabledModules
    patches
    ;
  artifactName = "${final.pname}-${final.version}";
  tools = {
    inherit
      python
      gnumake
      gnutar
      xz
      gzip
      findutils
      patch
      sed
      grep
      gawk
      diffutils
      file
      binutils
      patchelf
      ;
  };

  dependencyProviders = final.tools;
  environment = {
    tools = map (name: final.tools.${name}) [
      "gnumake"
      "findutils"
      "patch"
      "sed"
      "grep"
      "gawk"
      "diffutils"
      "file"
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
      tar = final.tools.gnutar;
      inherit (final.tools) xz findutils;
      compression = "xz";
    })
    (sourceCommand "python.validate-source" ''
      ${final.tools.python}/bin/python3 -B ${./prefix.py} "$PWD" ${lib.escapeShellArg sourceConfig} validate-source
    '')
    (steps.prepareAutotools {
      name = "python.autotools";
      bash = final.bash;
      inherit (final.tools) python;
      base = final.base;
    })
    (sourceCommand "python.prepare" ''
      ${lib.concatMapStringsSep "\n" (p: "${final.tools.patch}/bin/patch -p1 < ${p}") final.patches}
      ${final.tools.python}/bin/python3 -B ${./prefix.py} "$PWD" ${lib.escapeShellArg sourceConfig} prepare
      printf '%s\n' '*disabled*' ${lib.escapeShellArgs final.disabledModules} > Modules/Setup.local
    '')
    (sourceCommand "python.configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash
      ${final.bash}/bin/bash ./configure --prefix="$out" ${lib.escapeShellArgs final.configureFlags}
    '')
    (sourceCommand "python.build" ''
      ${final.tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash
    '')
    (sourceCommand "python.install" ''
      ${final.tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash "COMPILEALL_OPTS=-j$NIX_BUILD_CORES" install
      mkdir -p "$out/share/licenses/python"
      cp LICENSE "$out/share/licenses/python/"
    '')
    (steps.split "python.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    (command "python.relocate-prefix" ''
      ${final.tools.python}/bin/python3 -B ${../../python/native/relocate.py} "$out"
      ${prefix "install"}
      ${final.tools.python}/bin/python3 -B ${../../python/native/install.py} "$out" ${final.runtime.shell}/bin/bash ${
        lib.escapeShellArg (
          lib.makeBinPath [
            final.bash
            final.coreutils
            final.tools.sed
            final.tools.grep
            final.tools.diffutils
            final.tools.binutils
          ]
        )
      } \
        ${lib.escapeShellArg "${final.bash}/bin/bash"} ${lib.escapeShellArg "${final.runtime.shell}/bin/bash"}
    '')
    (transform (
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
    (transform (
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
      libraries = final.development.libraries;
    })
    (outputs.checkPaths {
      inherit (final.tools) python binutils patchelf;
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
    disabledModules = final.disabledModules;
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

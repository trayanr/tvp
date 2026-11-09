# 3.12.5: independent public source-GNU CPython build profile, one prefix stage.
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
      cwd = "source";
    };
  config = builtins.toJSON {
    shell = "${final.bash}/bin/bash";
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

  environment = {
    tools = with final.tools; [
      gnumake
      findutils
      patch
      sed
      grep
      gawk
      diffutils
      file
    ];
    libraries = [ ];
  };
  runtime = {
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
    (command "python.validate-source" ''
      ${final.tools.python}/bin/python3 -B ${./prefix.py} "$PWD" ${lib.escapeShellArg config} validate-source
    '')
    (steps.prepareAutotools {
      name = "python.autotools";
      bash = final.bash;
      inherit (final.tools) python;
      base = final.base;
    })
    (command "python.prepare" ''
      ${lib.concatMapStringsSep "\n" (p: "${final.tools.patch}/bin/patch -p1 < ${p}") final.patches}
      ${final.tools.python}/bin/python3 -B ${./prefix.py} "$PWD" ${lib.escapeShellArg config} prepare
      printf '%s\n' '*disabled*' ${lib.escapeShellArgs final.disabledModules} > Modules/Setup.local
    '')
    (command "python.configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash
      ${final.bash}/bin/bash ./configure --prefix="$out" ${lib.escapeShellArgs final.configureFlags}
    '')
    (command "python.build" ''
      ${final.tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash
      ./python -c 'import sys, json, subprocess, sysconfig'
    '')
    (command "python.install" ''
      ${final.tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash "COMPILEALL_OPTS=-j$NIX_BUILD_CORES" install
      mkdir -p "$out/share/licenses/python"
      cp LICENSE "$out/share/licenses/python/"
      ${prefix "install"}
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
    (command "python.installed-profile" ''
      "$out/bin/python3" -I -c 'import sys, json, subprocess, sysconfig'
    '')
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

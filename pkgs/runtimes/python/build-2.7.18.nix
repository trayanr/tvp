# CPython 2.7 detects C extension dependencies through its own setup.py.
{
  tvp,
  lib,
  base,
  src,
  version,
  runtimeBash,
  openssl,
  zlib,
  bzip2,
  libffi,
  sqlite,
  gdbm,
  readline,
  ncurses,
  libxcrypt,
}:
final:
let
  inherit (tvp.builder.forBase final.base) steps outputs tools;
  command = steps.command { environment = final.environment; };
  libraries = [
    final.openssl
    final.zlib
    final.bzip2
    final.libffi
    final.sqlite
    final.gdbm
    final.readline
    final.ncurses
    final.libxcrypt
  ];
  includeFlags = map (library: "-I${lib.getDev library}/include") libraries ++ [
    "-I${lib.getDev final.ncurses}/include/ncursesw"
  ];
  linkFlags = map (library: "-L${lib.getLib library}/lib") libraries;
  make = ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash'';
  paths = [
    "bin"
    "lib"
  ];
in
{
  pname = "python";
  artifactName = "${final.pname}-${final.version}";
  inherit
    base
    src
    version
    openssl
    zlib
    bzip2
    libffi
    sqlite
    gdbm
    readline
    ncurses
    libxcrypt
    ;
  inherit (tools) bash coreutils;
  buildFeatures = {
    # These extensions need providers outside the current TVP catalogue.
    disabledModules = [
      "_bsddb"
      "bsddb185"
      "_tkinter"
      "nis"
    ];
    unicodeWidth = "ucs4";
  };
  installedInterface = {
    executable = "python2.7";
    configTool = "python2.7-config";
    pkgConfig = "python-2.7";
  };
  environment = {
    tools = [
      tools.gnumake
      tools.gawk
      tools.grep
      tools.sed
      tools.diffutils
      tools.findutils
      tools.pkg-config
    ];
    inherit libraries;
    overrides.values = {
      CPPFLAGS = lib.concatStringsSep " " includeFlags;
      LDFLAGS = lib.concatStringsSep " " linkFlags;
    };
  };
  runtime = {
    inherit libraries;
    shell = runtimeBash;
  };
  plan = [
    (steps.unpack { src = final.src; compression = "xz"; })
    (steps.prepareAutotools { name = "python.autotools"; })
    (command "python.prepare" ''
      test "$(grep -Fxc 'disabled_module_list = []' setup.py)" -eq 1
      sed -i 's/^disabled_module_list = \[\]$/disabled_module_list = ${builtins.toJSON final.buildFeatures.disabledModules}/' setup.py
      # Use the selected Bash when subprocess requests a POSIX shell.
      test "$(grep -Fc 'args = ["/bin/sh", "-c"] + args' Lib/subprocess.py)" -eq 1
      sed -i 's|args = \["/bin/sh", "-c"\] + args|args = ["${final.runtime.shell}/bin/bash", "-c"] + args|' Lib/subprocess.py
    '')
    (command "python.configure" ''
      export CONFIG_SHELL=${tools.bash}/bin/bash
      export CFLAGS="''${CFLAGS:--O2} -std=gnu17"
      export LIBS="-lcrypt ''${LIBS:-}"
      "$CONFIG_SHELL" ./configure --prefix="$out" --libdir="$out/lib" \
        --enable-shared --with-system-ffi --with-dbmliborder=gdbm \
        --enable-unicode=${final.buildFeatures.unicodeWidth} --with-ensurepip=install
    '')
    (command "python.build" make)
    (command "python.install" ''
      ${make} install
      install -Dm644 LICENSE "$out/share/licenses/python/LICENSE"
      test -x "$out/bin/${final.installedInterface.executable}"
      test -x "$out/bin/${final.installedInterface.configTool}"
      test -f "$out/lib/pkgconfig/${final.installedInterface.pkgConfig}.pc"
      test -f "$out/include/python2.7/Python.h"
      test -e "$out/lib/libpython2.7.so"
    '')
    (steps.split "python.finalize")
    (outputs.copyArtifacts { })
    {
      name = "python.relocate";
      tools = [ tools.python ];
      # Equal-width output names preserve compiled and marshaled path lengths.
      run = ''${tools.python}/bin/python3 -B ${../../libraries/jdk-support-relocate.py} "$out" "$TVP_ARTIFACT_ROOT"'';
    }
    (outputs.shebangs {
      paths = [ "bin" ];
      names = [ "python" "python2" "python2.7" ];
      selfInterpreter = "bin/${final.installedInterface.executable}";
    })
    (outputs.strip { inherit paths; elfKinds = [ "runtime" ]; })
    (outputs.stripArchives { paths = [ "lib" ]; })
    (outputs.rpaths { inherit paths; libraries = final.runtime.libraries; elfKinds = [ "runtime" ]; })
    (outputs.development { libraries = [ final.libxcrypt ]; })
    (outputs.checkPaths { inherit paths; elfKinds = [ "runtime" ]; })
  ];
  meta = {
    description = "CPython interpreter and development interfaces";
    homepage = "https://www.python.org/";
    license = lib.licenses.psfl;
    platforms = [ "x86_64-linux" ];
    mainProgram = "python2";
  };
}

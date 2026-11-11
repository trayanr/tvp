# 3.0.0–3.47.2: Fossil autoconf source. Upstream make owns multi-file
# and (from 3.3.14) generated amalgamation plans; no newest-source substitutions.
{
  tvp,
  lib,
  base,
  src,
  version,
  bash,
  coreutils,
  pkgConfig,
  gnumake,
  gnutar,
  gzip,
  findutils,
  sed,
  grep,
  gawk,
  diffutils,
  patch,
  python,
  binutils,
  patchelf,
  tcl,
  readline,
  testZlib,
  compileFlags ? [ ],
  configureIsExecutable ? true,
  hardeningDisable ? [ ],
  pkgConfigMajorMinor ? false,
  reportedVersion ? version,
  patches ? [ ],
  prepareScript ? ./prepare.py,
  captureScript ? ./capture.sh,
  classifyScript ? ./classify.py,
  finalizeScript ? ./finalize.py,
}:
final:
let
  inherit (tvp.builder) steps outputs;
  environment = final.base.environment final.environment;
  command =
    name: run:
    environment
    // {
      name = "sqlite.${name}";
      cwd = "source";
      env = environment.env // {
        NIX_CFLAGS_COMPILE =
          environment.env.NIX_CFLAGS_COMPILE + " " + lib.concatStringsSep " " final.compileFlags;
        # Readline and Tcl carry transitive shared providers. These are search-only
        # flags, not undeclared direct libraries or installed feature switches.
        NIX_LDFLAGS =
          environment.env.NIX_LDFLAGS
          + " -rpath-link ${final.readline.tvp.deps.ncurses}/lib"
          + " -rpath-link ${final.tcl.tvp.deps.zlib}/lib";
      };
      run =
        "export NIX_HARDENING_ENABLE="
        + lib.escapeShellArg (
          lib.concatStringsSep " " (
            lib.subtractLists final.hardeningDisable final.base.compiler.defaultHardeningFlags
          )
        )
        + "\nexport NIX_HARDENING_DISABLE="
        + lib.escapeShellArg (lib.concatStringsSep " " final.hardeningDisable)
        + "\n"
        + run;
    };
  make = ''${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash TCLLIBDIR="$out/lib/tcl"'';
  finalCommand = name: run: {
    name = "sqlite.${name}";
    tools = [ final.python ];
    inherit run;
  };
in
{
  pname = "sqlite";
  inherit
    base
    src
    version
    bash
    coreutils
    ;
  inherit
    pkgConfig
    gnumake
    gnutar
    gzip
    findutils
    sed
    grep
    gawk
    diffutils
    patch
    python
    binutils
    patchelf
    tcl
    readline
    testZlib
    ;
  inherit
    compileFlags
    configureIsExecutable
    hardeningDisable
    pkgConfigMajorMinor
    reportedVersion
    patches
    prepareScript
    captureScript
    classifyScript
    finalizeScript
    ;
  environment = {
    tools = [
      final.gnumake
      final.pkgConfig
      final.sed
      final.grep
      final.gawk
      final.diffutils
      final.findutils
      final.tcl
    ];
    libraries = [ final.readline ];
  };
  runtime.libraries = [
    final.readline
    final.tcl
  ];
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = final.gnutar;
      inherit (final) gzip findutils;
      compression = "gzip";
    })
    (command "prepare" ''
      ${final.python}/bin/python3 -B ${final.prepareScript} "$PWD" ${
        if final.configureIsExecutable then "executable" else "make-executable"
      }
      ${lib.concatMapStringsSep "\n" (p: "${final.patch}/bin/patch -p1 < ${p}") final.patches}
    '')
    (steps.prepareAutotools {
      name = "sqlite.autotools-shells";
      inherit (final) bash python base;
    })
    (command "configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash
      export CC_FOR_BUILD="$CC"
      mkdir -p "$out/lib/tcl"
      export TCLLIBPATH="$out/lib/tcl"
      # Early configure reads config_TARGET_*; later TEA uses --with-tcl.
      # Both explicitly name the installed Tcl8 provider, never an FHS search.
      export config_TARGET_TCL_INC="-I${final.tcl}/include"
      export config_TARGET_TCL_LIBS="-L${final.tcl}/lib -ltcl8.6 -lm -ldl"
      export config_TARGET_READLINE_INC="-I${final.readline}/include"
      export config_TARGET_READLINE_LIBS="-L${final.readline}/lib -lreadline"
      ./configure --prefix="$out" --enable-all --enable-shared --enable-static \
        --with-tcl=${final.tcl}/lib --with-tclsh=${final.tcl}/bin/tclsh \
        --with-readline-inc=-I${final.readline}/include --with-readline-lib=-lreadline
    '')
    (command "build" ''${make} all'')
    (command "check-build" ''
      # Fixture-only zlib and target Tcl linkage never change installed features.
      export NIX_CFLAGS_COMPILE="$NIX_CFLAGS_COMPILE -isystem ${final.testZlib}/include -DSQLITE_HAVE_ZLIB=1"
      export NIX_LDFLAGS="$NIX_LDFLAGS -L${final.testZlib}/lib -rpath ${final.testZlib}/lib -L${final.tcl}/lib -rpath ${final.tcl}/lib"
      ${make} testfixture
    '')
    (command "check-raw" ''
      export HOME="$TMPDIR" TERM=xterm TZ=UTC
      ${final.bash}/bin/bash ${final.captureScript} "$out/nix-support/sqlite-upstream" \
        ${final.coreutils}/bin/timeout 900 ./testfixture test/quick.test
    '')
    (command "install" ''
      export TCLLIBPATH="$out/lib/tcl"
      ${make} install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
      test -x "$out/bin/sqlite3"
      test -f "$out/lib/libsqlite3.a"
      test -f "$out/lib/libsqlite3.so"
      test -f "$out/include/sqlite3.h"
    '')
    (steps.split "sqlite.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    (finalCommand "accept-upstream" ''
      ${final.python}/bin/python3 -B ${final.classifyScript} "$out/nix-support/sqlite-upstream"
    '')
    (finalCommand "relocate-installed-text" ''
      ${final.python}/bin/python3 -B ${final.finalizeScript} "$out"
    '')
    (finalCommand "compress-manual" ''
      if [[ -f "$out/share/man/man1/sqlite3.1" ]]; then
        ${final.gzip}/bin/gzip -n "$out/share/man/man1/sqlite3.1"
      fi
    '')
    (outputs.strip {
      inherit (final) python binutils;
      paths = [
        "bin"
        "lib"
      ];
    })
    (outputs.stripArchives {
      inherit (final) python binutils;
      paths = [ "lib" ];
    })
    (outputs.rpaths {
      inherit (final)
        python
        binutils
        patchelf
        base
        ;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
      paths = [
        "bin"
        "lib"
      ];
    })
    (outputs.development {
      python = final.python;
      libraries = [ ];
    })
    (outputs.checkPaths {
      inherit (final) python binutils patchelf;
      paths = [
        "bin"
        "lib"
      ];
    })
  ];
  tvp = {
    reportedVersion = final.reportedVersion;
    pkgConfigVersion =
      if final.pkgConfigMajorMinor then lib.versions.majorMinor final.version else final.version;
    features = {
      pkgConfig = lib.versionAtLeast final.version "3.0.6";
      prepareV2 = lib.versionAtLeast final.version "3.3.9";
      libVersionFunction = lib.versionAtLeast final.version "3.0.8";
    };
  };
  meta = {
    description = "Self-contained SQL database engine";
    homepage = "https://sqlite.org/";
    license = lib.licenses.publicDomain;
    platforms = [ "x86_64-linux" ];
  };
}

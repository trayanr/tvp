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
  testPatches ? [ ],
  testCompileFlags ? [ ],
  runnerScript ? ../tests/upstream-runner.tcl,
  upstreamExpected ? "SQLite upstream raw result accepted",
  testRestoreScript ? ../tests/upstream-restore.py,
  testPrepareScript ? ../tests/upstream-prepare.py,
  stateScript ? ./build-state.py,
  stateManifest ? ./retained-state.json,
  compileFlags ? [ ],
  testFixtureRelinks ? false,
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
    testPatches
    testCompileFlags
    runnerScript
    upstreamExpected
    testPrepareScript
    testRestoreScript
    stateScript
    stateManifest
    ;
  inherit
    compileFlags
    testFixtureRelinks
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
  productionSharedProviders = [ final.tcl.tvp.deps.zlib ];
  upstreamBuilder = tvp.builder;
  upstreamIsolation = {
    schema = 1;
    protocol = "quick";
    statePath = "nix-support/upstream-build-tree";
    productionSteps = [
      "source.unpack"
      "sqlite.prepare"
      "sqlite.autotools-shells"
      "sqlite.configure"
      "sqlite.build"
      "sqlite.install"
      "sqlite.save-build-tree"
    ];
    finalSteps = [
      "output.copy-artifacts"
      "sqlite.drop-build-tree"
      "sqlite.relocate-installed-text"
      "sqlite.compress-manual"
      "output.strip"
      "output.strip-archives"
      "output.rpaths"
      "output.development"
      "output.check-paths"
    ];
    testInputFields = [
      "testZlib"
      "testPatches"
      "testCompileFlags"
      "testFixtureRelinks"
      "testPrepareScript"
      "testRestoreScript"
      "captureScript"
      "classifyScript"
      "runnerScript"
      "upstreamExpected"
    ];
  };
  plan =
    map
      (
        step:
        if (step.kind or "command") == "split" then
          step
        else
          step
          // {
            upstreamRole =
              if builtins.elem step.name final.upstreamIsolation.productionSteps then
                "production"
              else
                "finalization";
          }
      )
      (
        steps.sequence [
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
          (command "build" "${make} all")
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
          (command "save-build-tree" ''
            ${final.python}/bin/python3 -B ${final.stateScript} save "$PWD" \
              "$out/nix-support/upstream-build-tree" ${final.stateManifest} quick "$out" \
              "$TVP_SOURCE_ROOT/source-date-epoch"
          '')
          (steps.split "sqlite.finalize")
          (outputs.copyArtifacts { coreutils = final.coreutils; })
          (finalCommand "drop-build-tree" ''
            ${final.coreutils}/bin/rm -rf -- "$out/nix-support/upstream-build-tree"
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
        ]
      );
  tvp = {
    testDeps = {
      inherit (final) testZlib;
      patches = final.testPatches;
      compileFlags = final.testCompileFlags;
      inherit (final)
        testFixtureRelinks
        testPrepareScript
        testRestoreScript
        captureScript
        classifyScript
        runnerScript
        upstreamExpected
        ;
    };
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

# Complete SQLite autosetup procedure; independent checkpoint T/R/U is unchanged.
{
  tvp,
  lib,
  base,
  src,
  version,
  tcl,
  readline,
  testZlib,
  buildFeatures ? { },
  sourceLayout ? { },
  installedInterface ? { },
  patches ? [ ],
  testPatches ? [ ],
  testCompileFlags ? [ ],
  testFixtureRelinks ? false,
  runnerScript ? ./tests/upstream-runner.tcl,
  upstreamExpected ? "SQLite upstream raw result accepted",
  testRestoreScript ? ./tests/upstream-restore.py,
  testPrepareScript ? ./tests/upstream-prepare.py,
  stateScript ? ./ordinary/build-state.py,
  stateManifest ? ./ordinary/retained-state.json,
  prepareScript ? ./ordinary/prepare.py,
  captureScript ? ./ordinary/capture.sh,
  classifyScript ? ./ordinary/classify.py,
  finalizeScript ? ./ordinary/finalize.py,
}:
final:
let
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs tools;
  environment = final.base.environment final.environment;
  command =
    name: run:
    environment
    // {
      name = "sqlite.${name}";
      cwd = "source";
      env = environment.env // {
        NIX_CFLAGS_COMPILE =
          environment.env.NIX_CFLAGS_COMPILE
          + " "
          + lib.concatStringsSep " " final.buildFeatures.compileFlags;
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
            lib.subtractLists final.buildFeatures.hardeningDisable final.base.compiler.defaultHardeningFlags
          )
        )
        + "\nexport NIX_HARDENING_DISABLE="
        + lib.escapeShellArg (lib.concatStringsSep " " final.buildFeatures.hardeningDisable)
        + "\n"
        + run;
    };
  make = ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash TCLLIBDIR="$out/lib/tcl"'';
  finalCommand = name: run: {
    name = "sqlite.${name}";
    tools = [ tools.python ];
    inherit run;
  };
in
{
  pname = "sqlite";
  inherit
    base
    src
    version
    tcl
    readline
    patches
    ;
  inherit (tools) bash coreutils;
  buildFeatures = {
    compileFlags = [ ];
    hardeningDisable = [ ];
  }
  // buildFeatures;
  sourceLayout = {
    compression = "gzip";
    configureIsExecutable = true;
  }
  // sourceLayout;
  installedInterface = {
    nativeProfile = false;
    reportedVersion = final.version;
    pkgConfigMajorMinor = false;
  }
  // installedInterface;
  # These names are the existing specialized isolation protocol, not standard tools.
  inherit
    testZlib
    testPatches
    testCompileFlags
    testFixtureRelinks
    runnerScript
    upstreamExpected
    testRestoreScript
    testPrepareScript
    stateScript
    stateManifest
    prepareScript
    captureScript
    classifyScript
    finalizeScript
    ;
  checkPatches = tvp.lib.packages.checkPatches;
  environment = {
    tools = [
      tools.gnumake
      tools.pkg-config
      tools.sed
      tools.grep
      tools.gawk
      tools.diffutils
      tools.findutils
      final.tcl
    ];
    libraries = [ final.readline ];
  };
  runtime.libraries = [ final.readline ];
  productionSharedProviders = [ final.tcl.tvp.deps.zlib ];
  upstreamBuilder = tvp.builder;
  upstreamIsolation = {
    schema = 1;
    protocol = "veryquick";
    statePath = "nix-support/upstream-build-tree";
    productionSteps = [
      "source.unpack"
      "sqlite.prepare"
      "sqlite.autosetup-shells"
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
            compression = final.sourceLayout.compression;
          })
          (command "prepare" ''
            ${tools.python}/bin/python3 -B ${final.prepareScript} "$PWD" ${
              if final.sourceLayout.configureIsExecutable then "executable" else "make-executable"
            }
            ${lib.concatMapStringsSep "\n" (p: "${tools.patch}/bin/patch -p1 < ${p}") final.patches}
          '')
          (steps.shebangs {
            name = "sqlite.autosetup-shells";
            paths = [
              "configure"
              "autosetup"
              "tool"
            ];
            names = [
              "sh"
              "bash"
            ];
            interpreter = "${final.bash}/bin/bash";
          })
          (command "configure" ''
            export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash
            export CC_FOR_BUILD="$CC"
            mkdir -p "$out/lib/tcl"
            export TCLLIBPATH="$out/lib/tcl"
            export autosetup_tclsh=${final.tcl}/bin/tclsh
            ./configure --prefix="$out" --all --enable-shared --enable-static \
              --enable-tcl --with-tcl=${final.tcl}/lib --with-tclsh=${final.tcl}/bin/tclsh \
              --enable-readline --with-readline-header=${final.readline}/include/readline/readline.h \
              --with-readline-ldflags="-L${final.readline}/lib -lreadline" \
              TCLLIBDIR="$out/lib/tcl"
            grep -Fx 'HAVE_TCL = 1' Makefile
            grep -Fx 'TCL_CONFIG_SH = ${final.tcl}/lib/tclConfig.sh' Makefile
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
            ${tools.python}/bin/python3 -B ${final.stateScript} save "$PWD" \
              "$out/nix-support/upstream-build-tree" ${final.stateManifest} veryquick "$out" \
              "$TVP_SOURCE_ROOT/source-date-epoch"
          '')
          (steps.split "sqlite.finalize")
          (outputs.copyArtifacts { })
          (finalCommand "drop-build-tree" ''
            ${final.coreutils}/bin/rm -rf -- "$out/nix-support/upstream-build-tree"
          '')
          (finalCommand "relocate-installed-text" ''
            ${tools.python}/bin/python3 -B ${final.finalizeScript} "$out"
          '')
          (finalCommand "compress-manual" ''
            if [[ -f "$out/share/man/man1/sqlite3.1" ]]; then
              ${tools.gzip}/bin/gzip -n "$out/share/man/man1/sqlite3.1"
            fi
          '')
          (outputs.strip {
            paths = [
              "bin"
              "lib"
            ];
          })
          (outputs.stripArchives {
            paths = [ "lib" ];
          })
          (outputs.rpaths {
            libraries = final.runtime.libraries;
            dlopenDirectories = final.runtime.dlopenDirectories or [ ];
            paths = [
              "bin"
              "lib"
            ];
          })
          (outputs.development {
            libraries = [ ];
          })
          (outputs.checkPaths {
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
    reportedVersion = final.installedInterface.reportedVersion;
    pkgConfigVersion =
      if final.installedInterface.pkgConfigMajorMinor then
        lib.versions.majorMinor final.version
      else
        final.version;
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

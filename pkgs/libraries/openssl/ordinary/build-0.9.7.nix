# 0.9.7: make depend; install versus install_sw before 0.9.7e: COMPLETE independent native procedure; source distinctions are definition data.
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
  python,
  binutils,
  patchelf,
  buildPerl,
  perl,
  runtimeCoreutils,
  runtimeSed,
  runtimeGrep,
  runtimeGawk,
  runtimeFindutils,
  testPatchTool,
  doCheck ? true,
  cStandard ? null,
  compileFlags ? [ ],
  testPatches ? [ ],
  testCompileFlags ? [ ],
  upstreamExpected ? "OpenSSL upstream raw result accepted",
  hardeningDisable ? [ ],
  forceGccName ? false,
  installTarget ? (if lib.versionAtLeast version "0.9.7e" then "install_sw" else "install"),
  features,
  sourceEncoding ? "latin-1",
}:
final:
let
  inherit (tvp.builder) steps outputs;
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "openssl.${name}";
      cwd = "source";
      inherit run;
    };
  make = ''${final.gnumake}/bin/make -j1 SHELL=${final.bash}/bin/bash'';
  productionMake =
    make + (if lib.versionOlder final.version "0.9.8" then " 'DIRS=$(TVP_PRODUCTION_DIRS)'" else "");
  productionTargets =
    if lib.versionOlder final.version "0.9.8" then
      [ "all" ]
    else
      [
        "build_libs"
        "build_apps"
        "build_tools"
        "openssl.pc"
        "libssl.pc"
        "libcrypto.pc"
      ];
in
{
  pname = "openssl";
  # Keep compiled self strings, suffix pooling and stored lengths unchanged.
  artifactName = "${final.pname}-${final.version}";
  # Rebind both consumer adapters from the effective recipe option. The base
  # carries the selected underlying toolchain; it is never replaced by a global
  # compiler or a peer package procedure.
  base =
    if base.compiler ? hardeningPolicy then
      let
        policy = base.compiler.specification.policy // {
          disable = final.hardeningDisable;
        };
        bintools = base.compiler.bintools.override { inherit policy; };
        compiler = base.compiler.override { inherit policy bintools; };
      in
      base.override { inherit compiler; }
    else
      base;

  inherit
    src
    version
    bash
    coreutils
    pkgConfig
    gnumake
    gnutar
    gzip
    findutils
    sed
    grep
    gawk
    diffutils
    python
    binutils
    patchelf
    buildPerl
    perl
    runtimeCoreutils
    runtimeSed
    runtimeGrep
    runtimeGawk
    runtimeFindutils
    testPatchTool
    doCheck
    cStandard
    compileFlags
    testPatches
    testCompileFlags
    upstreamExpected
    hardeningDisable
    forceGccName
    installTarget
    features
    sourceEncoding
    ;
  stateScript = ./build-state.py;
  stateManifest = ./build-state.json;
  testPrepareScript = ../tests/upstream-prepare.py;
  testRestoreScript = ../tests/upstream-restore.py;
  captureScript = ../tests/upstream-capture.py;
  classifyScript = ../tests/upstream-classify.py;
  runnerScript = ../tests/upstream-run.sh;
  testPerl = final.buildPerl;
  testTools = [ final.testPerl ];
  # Inherit the same selected base environment as the former raw check.
  testEnvironment = { };
  upstreamIsolation = {
    schema = 1;
    protocol = "openssl-0.9.7";
    statePath = "nix-support/upstream-build-tree";
    testInputFields = [
      "doCheck"
      "testPerl"
      "testTools"
      "testPatchTool"
      "testPatches"
      "testCompileFlags"
      "testEnvironment"
      "testPrepareScript"
      "testRestoreScript"
      "captureScript"
      "classifyScript"
      "runnerScript"
      "upstreamExpected"
    ];
    productionSteps = [
      "source.unpack"
      "openssl.prepare"
      "openssl.configure"
      "openssl.depend"
      "openssl.build"
      "openssl.install"
      "openssl.save-build-state"
    ];
    finalSteps = [
      "output.copy-artifacts"
      "openssl.drop-build-state"
      "openssl.relocate"
      "output.strip"
      "output.strip-archives"
      "openssl.self-runtime"
      "output.rpaths"
      "output.development"
      "output.check-paths"
    ];
  };
  sourceHelper = ./source.py;
  finalHelper = ./output.py;
  # Final-only source binding; edits here never enter preparation/compilation.
  manualHelper = ./manuals.py;
  manualRenderer = ./manual-render.pl;
  manualSource = final.src;
  manualEncoding = final.sourceEncoding;
  manualPerl = final.buildPerl;
  manualSections = [
    {
      directory = "doc/apps";
      section = "1";
      exceptions = {
        config = "5";
      };
    }
    {
      directory = "doc/crypto";
      section = "3";
      exceptions = {
        des_modes = "7";
      };
    }
    {
      directory = "doc/ssl";
      section = "3";
      exceptions = { };
    }
  ];
  archiveHelper = ./archive.py;
  elfHelper = ./elf.py;
  # Shared pure tree/text inspection owns no family mutations or recipe.
  inspectionHelper = ../../../../lib/installed-tree.py;
  configureFlags = [
    "shared"
    "--openssldir=etc/ssl"
  ] ++ [ ] ++ lib.optional (final.cStandard != null) "-std=${final.cStandard}" ++ final.compileFlags;
  environment = {
    tools = [
      final.coreutils
      final.buildPerl
      final.pkgConfig
      final.gnumake
      final.sed
      final.grep
      final.gawk
      final.diffutils
      final.findutils
      final.python
    ];
    libraries = [ ];
  };
  dependencyProviders = {
    perl = final.runtime.perl;
  };
  # Installed helpers use registered runtime providers, independently of build tools.
  runtimeTools = [
    final.runtimeCoreutils
    final.runtimeSed
    final.runtimeGrep
    final.runtimeGawk
    final.runtimeFindutils
  ];
  runtime = {
    libraries = [ ];
    selfLibraryDirectories = [ "lib" ];
    perl = final.perl;
    shell = final.bash;
    tools = final.runtimeTools;
  };
  plan = steps.sequence (
    map
      (
        step:
        if (step.kind or "") == "split" then
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
      [
        (steps.unpack {
          src = final.src;
          tar = final.gnutar;
          inherit (final) gzip findutils;
          compression = "gzip";
        })
        (command "prepare" ''
          ${final.python}/bin/python3 -B ${final.sourceHelper} ${final.bash}/bin/bash ${final.buildPerl}/bin/perl ${final.coreutils} ${lib.escapeShellArg final.sourceEncoding}
        '')
        (command "configure" ''
          export PERL=${final.buildPerl}/bin/perl HASHBANGPERL=${final.buildPerl}/bin/perl
          ${lib.optionalString final.forceGccName ''export CC=gcc''}
          export LDFLAGS="''${LDFLAGS:-} -Wl,-rpath,$out/lib"
          ${final.buildPerl}/bin/perl ./Configure linux-x86_64 --prefix="$out" ${lib.escapeShellArgs final.configureFlags}
        '')
        (command "depend" ''${make} depend'')
        (command "build" "${productionMake} ${lib.escapeShellArgs productionTargets}")
        (command "install" ''
          ${productionMake} ${lib.escapeShellArg final.installTarget}
          # 0.9.7c chmods the directory rather than its .pc files.
          if test -d "$out/lib/pkgconfig"; then chmod 755 "$out/lib/pkgconfig"; fi
          mkdir -p "$out/nix-support"
          cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
        '')
        (command "save-build-state" ''
          ${final.python}/bin/python3 -B ${final.stateScript} save "$PWD" \
            "$out/${final.upstreamIsolation.statePath}" ${final.stateManifest} \
            ${final.upstreamIsolation.protocol} "$out" "$TVP_SOURCE_ROOT/source-date-epoch"
        '')
        (steps.split "openssl.finalize")
        (outputs.copyArtifacts { coreutils = final.coreutils; })
        {
          name = "openssl.drop-build-state";
          tools = [ final.coreutils ];
          run = ''rm -rf -- "$out/${final.upstreamIsolation.statePath}"'';
        }
        {
          name = "openssl.relocate";
          tools = [
            final.python
            final.binutils
            final.patchelf
            final.manualPerl
          ];
          run = ''${final.python}/bin/python3 -B ${final.finalHelper} ${final.archiveHelper} ${final.inspectionHelper} "$out" "$TVP_ARTIFACT_ROOT" ${
            lib.escapeShellArg (
              builtins.toJSON {
                manual = {
                  source = toString final.manualSource;
                  version = final.version;
                  encoding = final.manualEncoding;
                  perl = "${final.manualPerl}/bin/perl";
                  renderHelper = "${final.manualRenderer}";
                  sections = final.manualSections;
                  epoch = "nix-support/source-date-epoch";
                };
                readelf = "${final.binutils}/bin/readelf";
                patchelf = "${final.patchelf}/bin/patchelf";
                perl = "${final.runtime.perl}/bin/perl";
                buildPerl = "${final.buildPerl}/bin/perl";
                shell = "${final.runtime.shell}/bin/bash";
                tools = map (p: "${p}/bin") final.runtime.tools;
                rehash = final.features.rehash;
              }
            )
          } ${final.elfHelper} ${final.manualHelper}'';
        }
        (outputs.strip {
          inherit (final) python binutils;
          paths = [
            "bin"
            "lib"
          ];
          elfKinds = [ "runtime" ];
        })
        (outputs.stripArchives {
          inherit (final) python binutils;
          paths = [ "lib" ];
        })
        {
          name = "openssl.self-runtime";
          tools = [
            final.python
            final.binutils
            final.patchelf
          ];
          # Seed the final self-library path before authoritative RPATH pruning.
          run = ''${final.python}/bin/python3 -B ${../../../../lib/append-self-rpaths.py} "$out" ${
            lib.escapeShellArg (
              builtins.toJSON {
                paths = [
                  "bin"
                  "lib"
                ];
                directories = final.runtime.selfLibraryDirectories;
                readelf = "${final.binutils}/bin/readelf";
                patchelf = "${final.patchelf}/bin/patchelf";
              }
            )
          } ${../../../../lib/native-output}'';
        }
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
          elfKinds = [ "runtime" ];
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
          elfKinds = [ "runtime" ];
        })
      ]
  );

  tvp.features = final.features;
  meta = {
    description = "A cryptographic library that implements the SSL and TLS protocols";
    homepage = "https://www.openssl.org/";
    license = lib.licenses.openssl;
    platforms = [ "x86_64-linux" ];
    mainProgram = "openssl";
  };
}

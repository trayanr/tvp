# 0.9.6 source-staged era: complete owned procedure, not an imported newer builder.
# Native x86_64 remains blocked: these sources predate the AMD64 Configure target.
# This era is UNQUALIFIED; retaining its procedure does not add architecture support.
{
  tvp,
  lib,
  base,
  src,
  version,
  buildPerl,
  perl,
  runtimeCoreutils,
  runtimeSed,
  runtimeGrep,
  runtimeGawk,
  runtimeFindutils,
  doCheck ? true,
  cStandard ? null,
  compileFlags ? [ ],
  testPatches ? [ ],
  testCompileFlags ? [ ],
  upstreamExpected ? "OpenSSL upstream raw result accepted",
  hardeningDisable ? [ ],
  forceGccName ? false,
  installTarget ? (if lib.versionAtLeast version "0.9.7e" then "install_sw" else "install"),
  installedInterface ? {
    sha256 = false;
    pbkdf2 = false;
    providers = false;
    engines = true;
    engineModules = false;
    splitPkgConfig = false;
    rehash = true;
    tlsMethod = false;
    modernCli = false;
    cmake = false;
  },
  sourceEncoding ? "latin-1",
}:
final:
let
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs tools;
  command =
    name:
    steps.command {
      environment = final.environment;
    } "openssl.${name}";
  make = "${tools.gnumake}/bin/make -j1 SHELL=${tools.bash}/bin/bash";
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
  # Preserve this family's existing seven-flag profile on the supplied base.
  # A caller-supplied adapter keeps its existing exclusions; requests add to them.
  base =
    if base.compiler ? hardeningPolicy then
      if final.hardeningDisable == [ ] then
        base
      else
        let
          policy = base.compiler.specification.policy // {
            disable = lib.unique (
              (base.compiler.specification.policy.disable or [ ]) ++ final.hardeningDisable
            );
          };
          bintools = base.compiler.bintools.override { inherit policy; };
          compiler = base.compiler.override { inherit policy bintools; };
        in
        base.override { inherit compiler; }
    else
      import ../../../bases/source-gnu/hardening {
        candidate = {
          inherit base;
          builder = tvp.builder;
          tools = (tvp.builder.forBase base).tools;
        };
        policy = {
          defaults = [
            "bindnow"
            "fortify"
            "format"
            "pic"
            "relro"
            "stackprotector"
            "strictoverflow"
          ];
          disable = final.hardeningDisable;
        };
      };

  inherit
    src
    version
    buildPerl
    perl
    runtimeCoreutils
    runtimeSed
    runtimeGrep
    runtimeGawk
    runtimeFindutils
    doCheck
    cStandard
    compileFlags
    testPatches
    testCompileFlags
    upstreamExpected
    hardeningDisable
    forceGccName
    installTarget
    sourceEncoding
    ;
  inherit (tools)
    bash
    coreutils
    python
    gnumake
    ;
  inherit installedInterface;
  testPatchTool = tools.patch;
  testPatchesValidated = tvp.lib.packages.checkPatches "openssl.testPatches" final.testPatches;
  buildFeatures = {
    shared = true;
    static = true;
    hardening =
      final.base.compiler.hardeningPolicy or {
        defaults = final.base.compiler.defaultHardeningFlags;
        disable = [ ];
        selected = final.base.compiler.defaultHardeningFlags;
      };
  };
  features = {
    inherit (final.buildFeatures) shared static;
  }
  // final.installedInterface;

  stateScript = ./ordinary/build-state.py;
  stateManifest = ./ordinary/build-state.json;
  testPrepareScript = ./tests/upstream-prepare.py;
  testRestoreScript = ./tests/upstream-restore.py;
  captureScript = ./tests/upstream-capture.py;
  classifyScript = ./tests/upstream-classify.py;
  runnerScript = ./tests/upstream-run.sh;
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
  sourceHelper = ./ordinary/source.py;
  finalHelper = ./ordinary/output.py;
  # Final-only source binding; edits here never enter preparation/compilation.
  manualHelper = ./ordinary/manuals.py;
  manualRenderer = ./ordinary/manual-render.pl;
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
  archiveHelper = ./ordinary/archive.py;
  elfHelper = ./ordinary/elf.py;
  # Shared pure tree/text inspection owns no family mutations or recipe.
  inspectionHelper = ../../../lib/installed-tree.py;
  configureFlags = [
    "shared"
    "--openssldir=etc/ssl"
  ]
  ++ [ ]
  ++ lib.optional (final.cStandard != null) "-std=${final.cStandard}"
  ++ final.compileFlags;
  environment = {
    tools = [
      tools.coreutils
      final.buildPerl
      tools.pkg-config
      tools.gnumake
      tools.sed
      tools.grep
      tools.gawk
      tools.diffutils
      tools.findutils
      tools.python
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
    shell = tools.bash;
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

          compression = "gzip";
        })
        (command "prepare" ''
          ${tools.python}/bin/python3 -B ${final.sourceHelper} ${tools.bash}/bin/bash ${final.buildPerl}/bin/perl ${tools.coreutils} ${lib.escapeShellArg final.sourceEncoding}
        '')
        (command "configure" ''
          export PERL=${final.buildPerl}/bin/perl HASHBANGPERL=${final.buildPerl}/bin/perl
          ${lib.optionalString final.forceGccName "export CC=gcc"}
          export LDFLAGS="''${LDFLAGS:-} -Wl,-rpath,$out/lib"
          ${final.buildPerl}/bin/perl ./Configure linux-x86_64 --prefix="$out" ${lib.escapeShellArgs final.configureFlags}
        '')
        (command "depend" "${make} depend")
        (command "build" "${productionMake} ${lib.escapeShellArgs productionTargets}")
        (command "install" ''
          ${productionMake} ${lib.escapeShellArg final.installTarget}
          # 0.9.7c chmods the directory rather than its .pc files.
          if test -d "$out/lib/pkgconfig"; then chmod 755 "$out/lib/pkgconfig"; fi
          mkdir -p "$out/nix-support"
          cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
        '')
        (command "save-build-state" ''
          ${tools.python}/bin/python3 -B ${final.stateScript} save "$PWD" \
            "$out/${final.upstreamIsolation.statePath}" ${final.stateManifest} \
            ${final.upstreamIsolation.protocol} "$out" "$TVP_SOURCE_ROOT/source-date-epoch"
        '')
        (steps.split "openssl.finalize")
        (outputs.copyArtifacts { })
        {
          name = "openssl.drop-build-state";
          tools = [ tools.coreutils ];
          run = ''rm -rf -- "$out/${final.upstreamIsolation.statePath}"'';
        }
        {
          name = "openssl.relocate";
          tools = [
            tools.python
            tools.binutils
            tools.patchelf
            final.manualPerl
          ];
          run = ''${tools.python}/bin/python3 -B ${final.finalHelper} ${final.archiveHelper} ${final.inspectionHelper} "$out" "$TVP_ARTIFACT_ROOT" ${
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
                readelf = "${tools.binutils}/bin/readelf";
                patchelf = "${tools.patchelf}/bin/patchelf";
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

          paths = [
            "bin"
            "lib"
          ];
          elfKinds = [ "runtime" ];
        })
        (outputs.stripArchives {

          paths = [ "lib" ];
        })
        {
          name = "openssl.self-runtime";
          tools = [
            tools.python
            tools.binutils
            tools.patchelf
          ];
          # Seed the final self-library path before authoritative RPATH pruning.
          run = ''${tools.python}/bin/python3 -B ${../../../lib/append-self-rpaths.py} "$out" ${
            lib.escapeShellArg (
              builtins.toJSON {
                paths = [
                  "bin"
                  "lib"
                ];
                directories = final.runtime.selfLibraryDirectories;
                readelf = "${tools.binutils}/bin/readelf";
                patchelf = "${tools.patchelf}/bin/patchelf";
              }
            )
          } ${../../../lib/native-output}'';
        }
        (outputs.rpaths {
          inherit (tools) python binutils patchelf;
          inherit (final) base;
          libraries = final.runtime.libraries;
          dlopenDirectories = final.runtime.dlopenDirectories or [ ];
          paths = [
            "bin"
            "lib"
          ];
          elfKinds = [ "runtime" ];
        })
        (outputs.development {
          python = tools.python;
          libraries = [ ];
        })
        (outputs.checkPaths {

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

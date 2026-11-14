# 3.13.7: independent native source SDK procedure. DevTools remain binary assets.
{
  tvp,
  lib,
  base,
  src,
  version,
  bootstrapDart,
  devtoolsAssets,
  python,
  llvm,
  gn,
  git,
  ninja,
  patchelf,
  bash,
  ca-certificates,
  fetchCertificates,
  sourceLocks,
  buildDevtoolsFromSources,
  useCipdToolchainStamps,
  patches,
  coreutils,
  gawk,
  helperPython,
  binutils,
  findutils,
  sed,
  grep,
  diffutils,
  curl,
  tar,
  gzip,
  patch,
  dynamicLinker ? null,
}:
final:
let
  inherit (tvp.builder) steps outputs;
  environment = final.base.environment final.environment;
  command =
    name: run:
    environment
    // {
      inherit name;
      cwd = "source";
      run =
        ''
          export XDG_CONFIG_HOME="$TVP_SOURCE_ROOT/work-cache/config" PUB_CACHE="$TVP_SOURCE_ROOT/work-cache/pub-cache"
          mkdir -p "$XDG_CONFIG_HOME" "$PUB_CACHE"
        ''
        + run;
    };
  dependencySources = map (
    entry:
    entry
    // {
      src = tvp.lib.sources.fetchArchive {
        inherit (entry) url sha256;
        inherit (final)
          bash
          curl
          tar
          gzip
          coreutils
          ;
        python = final.helperPython;
        certificates = final.fetchCertificates;
      };
    }
  ) final.sourceLocks;
  target = final.llvm.specification.runtime.target;
in
{
  pname = "dart";
  inherit
    base
    src
    version
    bootstrapDart
    devtoolsAssets
    python
    llvm
    gn
    git
    ninja
    patchelf
    bash
    sourceLocks
    buildDevtoolsFromSources
    useCipdToolchainStamps
    patches
    coreutils
    gawk
    helperPython
    binutils
    findutils
    sed
    grep
    diffutils
    curl
    fetchCertificates
    tar
    gzip
    patch
    dynamicLinker
    ;
  inherit ca-certificates;
  dependencyProviders.ca-certificates = final.runtime.certificates;
  runtime = {
    loader = if final.dynamicLinker == null then final.llvm.tvp.dynamicLinker else final.dynamicLinker;
    libraries = [
      target.libc
      target.gccRuntime
      target.cxxRuntime
    ];
    shell = "${final.bash}/bin/bash";
    certificates = final.ca-certificates;
  };
  environment = {
    tools = [
      final.coreutils
      final.findutils
      final.sed
      final.grep
      final.diffutils
      final.bootstrapDart
      final.python
      final.llvm
      final.gn
      final.git
      final.ninja
      final.patch
    ];
    libraries = [ ];
    overrides.values = {
      CC = "${final.llvm}/bin/clang";
      CXX = "${final.llvm}/bin/clang++";
      LD = "${final.llvm}/bin/ld.lld";
      AR = "${final.llvm}/bin/llvm-ar";
      RANLIB = "${final.llvm}/bin/llvm-ranlib";
      NM = "${final.llvm}/bin/llvm-nm";
      STRIP = "${final.llvm}/bin/llvm-strip";
      READELF = "${final.llvm}/bin/llvm-readelf";
      OBJCOPY = "${final.llvm}/bin/llvm-objcopy";
      # llvm-as assembles LLVM IR, not native assembly. Use LLVM's selected target assembler.
      AS = "${target.targetBinutils}/bin/as";
      DART_SUPPRESS_ANALYTICS = "true";
    };
  };
  plan =
    assert
      (!final.buildDevtoolsFromSources)
      || throw "Dart source DevTools profile is not supplied by this recipe";
    assert
      (!final.useCipdToolchainStamps)
      || throw "Dart CIPD stamp profile is unsupported for immutable store toolchains";
    steps.sequence [
      (
        (steps.unpack {
          inherit (final)
            src
            tar
            gzip
            findutils
            ;
          compression = "gzip";
        })
        // {
          tools = [
            final.tar
            final.gzip
            final.coreutils
            final.findutils
          ];
        }
      )
      (command "dart.prepare-deps" ''
        ${final.helperPython}/bin/python3 -B ${./prepare.py} \
          ${lib.escapeShellArg (builtins.toJSON dependencySources)} \
          ${lib.escapeShellArg (builtins.toJSON final.patches)} ${../../../../lib/native-output}
        ${lib.concatMapStringsSep "\n" (
          p: ''${final.patch}/bin/patch --dry-run --fuzz=0 -p1 < ${p}''
        ) final.patches}
        ${lib.concatMapStringsSep "\n" (p: ''${final.patch}/bin/patch --fuzz=0 -p1 < ${p}'') final.patches}
        printf '%s\n' 'build_devtools_from_sources = ${lib.boolToString final.buildDevtoolsFromSources}' > build/config/gclient_args.gni
        mkdir -p tools/sdks buildtools/linux-x64 third_party/devtools/web
        test ! -e tools/sdks/dart-sdk
        ln -s ${final.bootstrapDart} tools/sdks/dart-sdk
        ln -s ${final.gn}/bin/gn buildtools/gn
        ln -s ${final.llvm} buildtools/linux-x64/clang
        cp -a ${final.devtoolsAssets}/bin/resources/devtools/. third_party/devtools/web/
      '')
      (steps.shebangs {
        name = "dart.source-python";
        python = final.helperPython;
        paths = [
          "tools"
          "build"
          "runtime/tools"
        ];
        names = [
          "python"
          "python3"
        ];
        interpreter = "${final.python}/bin/python3";
      })
      (steps.shebangs {
        name = "dart.source-shell";
        python = final.helperPython;
        paths = [
          "tools"
          "build"
          "runtime/tools"
        ];
        names = [
          "sh"
          "bash"
        ];
        interpreter = "${final.bash}/bin/bash";
      })
      (command "dart.configure" ''
        ${final.python}/bin/python3 tools/generate_package_config.py
        ${final.python}/bin/python3 tools/generate_sdk_version_file.py
        PYTHONPATH="$PWD/tools" ${final.python}/bin/python3 - <<'PY'
        import os, sys
        sys.argv[0] = os.path.join(os.getcwd(), "tools", "gn.py")
        import gn
        options = gn.parse_args(${
          builtins.toJSON [
            "gn.py"
            "--mode=release"
            "--arch=x64"
            "--no-git-version"
            "--no-verify-sdk-hash"
            "--target-sysroot=x64=${final.llvm}/nix-support/empty-sysroot"
            ''--gn-args=use_custom_libcxx=false use_cipd_toolchain_stamps=${lib.boolToString final.useCipdToolchainStamps} llvm_linker_path="${final.llvm}/bin/ld.lld"''
          ]
        })
        sys.exit(gn.RunGnOnConfiguredConfigurations(options, os.environ.copy()))
        PY
      '')
      (command "dart.build" ''
        ${final.ninja}/bin/ninja -C out/ReleaseX64 -j"$NIX_BUILD_CORES" create_most_sdk
      '')
      (command "dart.upstream-check" ''
        for fixture in corelib/list_test corelib/map_test; do
          ${final.python}/bin/python3 tools/test.py --mode=release --arch=x64 --compiler=dartk --runtime=vm "$fixture"
        done
      '')
      (command "dart.install-raw-sdk" ''
        mkdir "$out"
        cp -a out/ReleaseX64/dart-sdk/. "$out/"
      '')
      (steps.split "dart.finalize")
      (outputs.copyArtifacts { inherit (final) coreutils; })
      (outputs.interpreters {
        python = final.helperPython;
        inherit (final) binutils patchelf;
        paths = [ "bin" ];
        loader = final.runtime.loader;
      })
      (outputs.rpaths {
        python = final.helperPython;
        inherit (final) binutils patchelf;
        paths = [ "bin" ];
        libraries = final.runtime.libraries;
        # No GNU base directories: the compiler's selected LLVM target owns this runtime.
      })
      (outputs.strip {
        python = final.helperPython;
        inherit (final) binutils;
        paths = [ "bin" ];
      })
      {
        name = "dart.unwrap";
        tools = [ final.coreutils ];
        run = ''mv "$out/bin/dart" "$out/bin/.dart-unwrapped"'';
      }
      (outputs.template {
        python = final.helperPython;
        path = "bin/dart";
        template = ../dart.sh;
        values = {
          bash = final.runtime.shell;
          certificates = "${final.runtime.certificates}/etc/ssl/certs/ca-bundle.crt";
          dart = "@OUTPUT@/bin/.dart-unwrapped";
        };
      })
      {
        name = "dart.installed-startup";
        tools = [ final.coreutils ];
        run = ''
          export DART_SUPPRESS_ANALYTICS=true XDG_CONFIG_HOME="$PWD/config" PUB_CACHE="$PWD/pub-cache"
          "$out/bin/dart" --version
          "$out/bin/dart" pub --help > pub-help
          test -s pub-help
        '';
      }
      (outputs.checkSymlinkTree {
        python = final.helperPython;
        paths = [ "bin" ];
      })
      (outputs.checkPaths {
        python = final.helperPython;
        inherit (final) binutils patchelf;
        paths = [ "bin" ];
      })
    ];
  sourceInputs = dependencySources;
  tvp.sourceLocks = final.sourceLocks;
  tvp.runtimeProviders = final.runtime;
  tvp.constructionDependencies.sourceFetch = {
    inherit (final)
      curl
      fetchCertificates
      tar
      gzip
      helperPython
      ;
  };
  tvp.dynamicLinker = final.runtime.loader;
  tvp.cc = final.llvm;
  tvp.targetRuntime = final.runtime.libraries;
  tvp.features = {
    jit = true;
    aot = true;
    ffi = true;
    javascript = true;
    wasm = true;
    sourceDevtools = false;
  };
  meta = {
    description = "Source-built Dart VM and language toolchain with pinned DevTools assets";
    homepage = "https://dart.dev/";
    license = lib.licenses.bsd3;
    sourceProvenance = [
      lib.sourceTypes.fromSource
      lib.sourceTypes.binaryBytecode
    ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "dart";
  };
}

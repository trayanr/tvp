# 3.47.8: pristine framework/assets artifact; final-prefix tool generation.
{
  tvp,
  lib,
  base,
  src,
  version,
  dart,
  git,
  curl,
  gradle,
  androidSdk,
  jdk,
  ca-certificates,
  bash,
  coreutils,
  findutils,
  sed,
  grep,
  diffutils,
  gawk,
  tar,
  gzip,
  xz,
  unzip,
  python,
  helperPython,
  binutils,
  patchelf,
  which,
  runtimeLibc,
  runtimeCompiler,
}:
final:
let
  inherit (tvp.builder) steps outputs;
  runtimePath = lib.makeBinPath [
    final.runtime.androidSdk
    final.runtime.which
    final.runtime.dart
    final.runtime.git
    final.runtime.curl
    final.runtime.gradle
    final.runtime.jdk
    final.coreutils
    final.findutils
    final.grep
    final.sed
    final.gawk
    final.tar
    final.gzip
    final.xz
    final.unzip
    final.runtime.shell
  ];
  command = name: run: {
    inherit name run;
    tools = [
      final.coreutils
      final.diffutils
    ];
  };
in
{
  pname = "flutter";
  inherit
    base
    src
    version
    bash
    coreutils
    findutils
    sed
    grep
    diffutils
    gawk
    tar
    gzip
    xz
    unzip
    helperPython
    binutils
    patchelf
    runtimeLibc
    runtimeCompiler
    ;
  # Exposed inputs supply defaults; explicit runtime edits take precedence.
  inherit
    dart
    git
    curl
    gradle
    androidSdk
    jdk
    python
    which
    ca-certificates
    ;
  dependencyProviders = {
    inherit (final.runtime)
      dart
      git
      curl
      gradle
      androidSdk
      jdk
      python
      which
      ;
    ca-certificates = final.runtime.certificates;
  };
  runtime = {
    inherit (final)
      dart
      git
      curl
      gradle
      androidSdk
      jdk
      python
      which
      ;
    certificates = final.ca-certificates;
    shell = final.bash;
    loader = "${final.runtimeLibc}/lib/ld-linux-x86-64.so.2";
    libraries = [
      final.runtimeLibc
      final.runtimeCompiler
    ];
  };
  environment = {
    tools = [
      final.coreutils
      final.tar
      final.xz
    ];
    libraries = [ ];
  };
  plan = steps.sequence [
    (
      (final.base.environment final.environment)
      // {
        name = "flutter.install-pristine";
        run = ''
          mkdir source
          ${final.tar}/bin/tar -xJf ${lib.escapeShellArg (toString final.src)} --strip-components=1 -C source
          mkdir -p "$out/libexec/flutter"
          cp -a source/. "$out/libexec/flutter/"
          chmod -R u+w "$out/libexec/flutter"
          rm -r "$out/libexec/flutter/bin/cache/dart-sdk"
          rm "$out/libexec/flutter/bin/cache/flutter_tools.snapshot"
        '';
      }
    )
    (steps.split "flutter.finalize")
    (outputs.copyArtifacts {
      inherit (final) coreutils;
      preserveHardlinks = false;
    })
    (command "flutter.bind-dart" ''
      sdk="$out/libexec/flutter"
      mkdir -p "$out/bin"
      cp ${../../../../lib/writable-sdk.sh} "$out/libexec/writable-sdk.sh"
      ln -s ${final.runtime.dart} "$sdk/bin/cache/dart-sdk"
    '')
    # Output-specific generation is intentional: the previous 45.8MB app-jit
    # snapshot embeds the final prefix 4678 times; package_config embeds it 103
    # times. Generate both AFTER copying. Never byte-replace a binary snapshot.
    {
      name = "flutter.generate-final-tool";
      tools = [
        final.runtime.dart
        final.runtime.git
        final.coreutils
        final.diffutils
      ];
      run = ''
        sdk="$out/libexec/flutter"
        export PUB_CACHE="$sdk/.pub-cache" XDG_CONFIG_HOME="$PWD/work-cache/config" DART_SUPPRESS_ANALYTICS=true
        export PATH=${lib.escapeShellArg runtimePath}:"$PATH"
        export ANDROID_HOME='${final.runtime.androidSdk}/${final.runtime.androidSdk.sdkPath}' JAVA_HOME='${final.runtime.jdk}'
        export FLUTTER_ROOT="$sdk" CI=true FLUTTER_SUPPRESS_ANALYTICS=true
        ${final.runtime.dart}/bin/dart pub cache preload "$sdk"/.pub-preload-cache/*.tar.gz
        cd "$sdk/packages/flutter_tools"
        cp pubspec.lock "$NIX_BUILD_TOP/flutter-tool.lock"
        ${final.runtime.dart}/bin/dart pub get --offline --enforce-lockfile
        cmp pubspec.lock "$NIX_BUILD_TOP/flutter-tool.lock"
        ${final.runtime.dart}/bin/dart --verbosity=error --snapshot="$sdk/bin/cache/flutter_tools.snapshot" --snapshot-kind=app-jit --packages=.dart_tool/package_config.json --no-enable-mirrors bin/flutter_tools.dart --help
        revision=$(${final.runtime.git}/bin/git -C "$sdk" rev-parse HEAD)
        printf '%s:\n' "$revision" > "$sdk/bin/cache/flutter_tools.stamp"
        touch pubspec.lock
      '';
    }
    (outputs.shebangs {
      python = final.helperPython;
      paths = [
        "libexec/flutter/bin"
        "libexec/flutter/packages/flutter_tools/bin"
      ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.runtime.shell}/bin/bash";
    })
    (outputs.hostELF {
      python = final.helperPython;
      inherit (final) binutils patchelf;
      paths = [ "libexec/flutter/bin/cache/artifacts/engine/linux-x64" ];
      patterns = [ "libexec/flutter/bin/cache/artifacts/engine/android-*/linux-x64" ];
      inherit (final.runtime) loader libraries;
      executablesOnly = true;
    })
    (command "flutter.internal-launcher" ''mv "$out/libexec/flutter/bin/flutter" "$out/libexec/flutter/bin/flutter-internal"'')
    (outputs.template {
      python = final.helperPython;
      path = "bin/flutter";
      template = ../flutter.sh;
      values = {
        bash = "${final.runtime.shell}/bin/bash";
        sdk = "@OUTPUT@/libexec/flutter";
        sdkHelper = "@OUTPUT@/libexec/writable-sdk.sh";
        inherit runtimePath;
        certificates = "${final.runtime.certificates}/etc/ssl/certs/ca-bundle.crt";
        androidSdk = "${final.runtime.androidSdk}/${final.runtime.androidSdk.sdkPath}";
        androidSdkTool = "${final.runtime.androidSdk}/bin/tvp-android-sdk";
        jdk = toString final.runtime.jdk;
        gradle = toString final.runtime.gradle;
      };
    })
    (command "flutter.publish" ''
      ln -s ${final.runtime.dart}/bin/dart "$out/bin/dart"
      test -s "$out/libexec/flutter/bin/cache/flutter_tools.snapshot"
      test -s "$out/libexec/flutter/packages/flutter_tools/.dart_tool/package_config.json"
    '')
  ];
  tvp.features = {
    headlessWidgets = true;
    web = true;
    android = true;
    linuxDesktop = false;
    emulator = false;
  };
  tvp.dynamicLinker = final.runtime.loader;
  tvp.runtimeProviders = final.runtime;
  tvp.toolGeneration = "final-prefix-offline-app-jit";
  meta = {
    description = "Flutter framework and rebuilt command tool with pinned engine artifacts";
    homepage = "https://flutter.dev/";
    license = lib.licenses.bsd3;
    sourceProvenance = [
      lib.sourceTypes.fromSource
      lib.sourceTypes.binaryNativeCode
      lib.sourceTypes.binaryBytecode
    ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "flutter";
  };
}

{
  lib,
  stdenv,
  fetchurl,
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
  gnugrep,
  gnused,
  gawk,
  gnutar,
  gzip,
  xz,
  unzip,
  python,
  patchelf,
  which,
  dynamicLinker,
  version,
  sha256,
  mkTests,
}:
let
  runtimePath = lib.makeBinPath [
    androidSdk
    which
    dart
    git
    curl
    gradle
    jdk
    coreutils
    findutils
    gnugrep
    gnused
    gawk
    gnutar
    gzip
    xz
    unzip
    bash
  ];
in
stdenv.mkDerivation (finalAttrs: {
  pname = "flutter";
  inherit version;
  src = fetchurl {
    url = "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${version}-stable.tar.xz";
    inherit sha256;
  };
  nativeBuildInputs = [
    dart
    git
    python
    patchelf
  ];
  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;
  dontPatchShebangs = true;
  installPhase = ''
    runHook preInstall
    sdk="$out/libexec/flutter"
    mkdir -p "$sdk" "$out/bin"
    cp -a . "$sdk/"
    cp ${../../../lib/writable-sdk.sh} "$out/libexec/writable-sdk.sh"
    chmod -R u+w "$sdk"
    rm -r "$sdk/bin/cache/dart-sdk"
    ln -s ${dart} "$sdk/bin/cache/dart-sdk"
    export PUB_CACHE="$sdk/.pub-cache" XDG_CONFIG_HOME="$TMPDIR/config" DART_SUPPRESS_ANALYTICS=true
    export PATH='${runtimePath}':"$PATH" ANDROID_HOME='${androidSdk}/${androidSdk.sdkPath}' JAVA_HOME='${jdk}'
    export FLUTTER_ROOT="$sdk" CI=true FLUTTER_SUPPRESS_ANALYTICS=true
    ${dart}/bin/dart pub cache preload "$sdk"/.pub-preload-cache/*.tar.gz
    # The shipped tool snapshot is discarded and rebuilt from its sources.
    rm "$sdk/bin/cache/flutter_tools.snapshot"
    cd "$sdk/packages/flutter_tools"
    cp pubspec.lock "$TMPDIR/flutter-tool.lock"
    ${dart}/bin/dart pub get --offline --enforce-lockfile
    cmp pubspec.lock "$TMPDIR/flutter-tool.lock"
    ${dart}/bin/dart --verbosity=error --snapshot="$sdk/bin/cache/flutter_tools.snapshot" --snapshot-kind=app-jit --packages=.dart_tool/package_config.json --no-enable-mirrors bin/flutter_tools.dart --help
    revision=$(${git}/bin/git -C "$sdk" rev-parse HEAD)
    printf '%s:\n' "$revision" > "$sdk/bin/cache/flutter_tools.stamp"
    touch pubspec.lock
    cd "$sdk"
    patchShebangs bin packages/flutter_tools/bin
    # Adapt host executables only. Android target libraries, target sysroots,
    # and unused desktop engine libraries retain their original bytes.
    while IFS= read -r -d "" binary; do
      if isELF "$binary"; then
        interpreter=$(patchelf --print-interpreter "$binary" 2>/dev/null || true)
        case "$interpreter" in
          */ld-linux-x86-64.so.2)
            patchelf --set-interpreter '${stdenv.cc.libc}/${dynamicLinker}' "$binary"
            old_rpath=$(patchelf --print-rpath "$binary")
            patchelf --set-rpath "$old_rpath:${stdenv.cc.libc}/lib:${lib.getLib stdenv.cc.cc}/lib" "$binary"
            patchelf --shrink-rpath "$binary"
            ;;
        esac
      fi
    done < <(find bin/cache -type f -print0)
    mv bin/flutter bin/flutter-internal
    substitute ${./flutter.sh} "$out/bin/flutter" \
      --subst-var-by bash '${bash}/bin/bash' \
      --subst-var-by sdk "$sdk" \
      --subst-var-by sdkHelper "$out/libexec/writable-sdk.sh" \
      --subst-var-by runtimePath '${runtimePath}' \
      --subst-var-by certificates '${ca-certificates}/etc/ssl/certs/ca-bundle.crt' \
      --subst-var-by androidSdk '${androidSdk}/${androidSdk.sdkPath}' \
      --subst-var-by androidSdkTool '${androidSdk}/bin/tvp-android-sdk' \
      --subst-var-by jdk '${jdk}' \
      --subst-var-by gradle '${gradle}'
    chmod +x "$out/bin/flutter"
    ln -s ${dart}/bin/dart "$out/bin/dart"
    runHook postInstall
  '';
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
  passthru = {
    tvp.deps = {
      inherit
        dart
        git
        curl
        gradle
        androidSdk
        jdk
        ca-certificates
        bash
        coreutils
        findutils
        gnugrep
        gnused
        gawk
        gnutar
        gzip
        xz
        unzip
        python
        patchelf
        which
        ;
    };
    tvp.features = {
      headlessWidgets = true;
      web = true;
      android = true;
      linuxDesktop = false;
      emulator = false;
    };
    tests = mkTests finalAttrs.finalPackage;
  };
})

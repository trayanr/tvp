{
  lib,
  stdenv,
  fetchurl,
  fetchzip,
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
  sourceLocks,
  buildDevtoolsFromSources,
  useCipdToolchainStamps,
  dynamicLinker,
  version,
  sha256,
  patches,
  mkTests,
}:
let
  dependencySources = map (
    entry:
    entry
    // {
      src = fetchzip {
        inherit (entry) url sha256;
        extension = "tar.gz";
        stripRoot = false;
      };
    }
  ) sourceLocks;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "dart";
  inherit version patches;
  src = fetchurl {
    url = "https://github.com/dart-lang/sdk/archive/refs/tags/${version}.tar.gz";
    inherit sha256;
  };
  nativeBuildInputs = [
    bootstrapDart
    python
    llvm
    gn
    git
    ninja
    patchelf
  ];
  env.DART_SUPPRESS_ANALYTICS = "true";
  postPatch = ''
    printf '%s\n' 'build_devtools_from_sources = ${lib.boolToString buildDevtoolsFromSources}' > build/config/gclient_args.gni
    ${lib.concatMapStringsSep "\n" (entry: ''
      mkdir -p ${lib.escapeShellArg entry.path}
      cp -a ${entry.src}/. ${lib.escapeShellArg entry.path}/
      chmod -R u+w ${lib.escapeShellArg entry.path}
    '') dependencySources}
    mkdir -p tools/sdks buildtools/linux-x64 third_party/devtools
    ln -s ${bootstrapDart} tools/sdks/dart-sdk
    ln -s ${gn}/bin/gn buildtools/gn
    ln -s ${llvm} buildtools/linux-x64/clang
    cp -a ${devtoolsAssets}/bin/resources/devtools/. third_party/devtools/web/
    patchShebangs tools build runtime/tools
  '';
  configurePhase = ''
    runHook preConfigure
    export XDG_CONFIG_HOME="$TMPDIR/config" PUB_CACHE="$TMPDIR/pub-cache"
    ${python}/bin/python3 tools/generate_package_config.py
    ${python}/bin/python3 tools/generate_sdk_version_file.py
    # Use the same explicit environment argument as upstream tools/build.py;
    # the standalone gn.py entry point otherwise starts GN with an empty one.
    PYTHONPATH="$PWD/tools" ${python}/bin/python3 - <<'PY'
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
        "--target-sysroot=x64=${llvm}/nix-support/empty-sysroot"
        ''--gn-args=use_custom_libcxx=false use_cipd_toolchain_stamps=${lib.boolToString useCipdToolchainStamps} llvm_linker_path="${llvm}/bin/ld.lld"''
      ]
    })
    sys.exit(gn.RunGnOnConfiguredConfigurations(options, os.environ.copy()))
    PY
    runHook postConfigure
  '';
  buildPhase = ''
    runHook preBuild
    ninja -C out/ReleaseX64 -j"$NIX_BUILD_CORES" create_most_sdk
    runHook postBuild
  '';
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    for fixture in corelib/list_test corelib/map_test; do
      ${python}/bin/python3 tools/test.py --mode=release --arch=x64 --compiler=dartk --runtime=vm "$fixture"
    done
    runHook postCheck
  '';
  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -a out/ReleaseX64/dart-sdk/. "$out/"
    while IFS= read -r -d "" binary; do
      if isELF "$binary"; then
        chmod u+w "$binary"
        if patchelf --print-interpreter "$binary" >/dev/null 2>&1; then
          patchelf --set-interpreter '${stdenv.cc.libc}/${dynamicLinker}' "$binary"
        fi
        patchelf --shrink-rpath "$binary"
      fi
    done < <(find "$out/bin" -type f -print0)
    mv "$out/bin/dart" "$out/bin/.dart-unwrapped"
    substitute ${./dart.sh} "$out/bin/dart" \
      --subst-var-by bash '${bash}/bin/bash' \
      --subst-var-by certificates '${ca-certificates}/etc/ssl/certs/ca-bundle.crt' \
      --subst-var-by dart "$out/bin/.dart-unwrapped"
    chmod +x "$out/bin/dart"
    runHook postInstall
  '';
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
  passthru = {
    tvp.deps = {
      inherit
        bootstrapDart
        devtoolsAssets
        python
        llvm
        gn
        git
        ninja
        patchelf
        bash
        ca-certificates
        ;
    };
    tvp.sourceLocks = sourceLocks;
    tvp.cc = stdenv.cc;
    tvp.features = {
      jit = true;
      aot = true;
      ffi = true;
      javascript = true;
      wasm = true;
      sourceDevtools = false;
    };
    tests = mkTests finalAttrs.finalPackage;
  };
})

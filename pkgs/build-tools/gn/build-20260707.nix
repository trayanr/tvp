{
  lib,
  stdenv,
  fetchzip,
  python,
  ninja,
  patchelf,
  revision,
  hardeningDisable,
  allowWarnings,
  version,
  sha256,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "gn";
  inherit version hardeningDisable;
  src = fetchzip {
    name = "gn-${revision}";
    extension = "tar.gz";
    stripRoot = false;
    url = "https://gn.googlesource.com/gn/+archive/${revision}.tar.gz";
    inherit sha256;
  };
  nativeBuildInputs = [
    python
    ninja
    patchelf
  ];
  configurePhase = ''
    runHook preConfigure
    export CXX='${stdenv.cc}/bin/c++' AR='${stdenv.cc.bintools}/bin/ar'
    ${python}/bin/python3 build/gen.py --no-last-commit-position --no-static-libstdc++ --no-strip ${lib.optionalString allowWarnings "--allow-warnings"}
    cat > out/last_commit_position.h <<'HEADER'
    #define LAST_COMMIT_POSITION_NUM 0
    #define LAST_COMMIT_POSITION "${revision}"
    HEADER
    runHook postConfigure
  '';
  buildPhase = ''
    runHook preBuild
    ninja -C out -j"$NIX_BUILD_CORES"
    runHook postBuild
  '';
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    out/gn_unittests
    runHook postCheck
  '';
  installPhase = ''
    runHook preInstall
    install -Dm755 out/gn "$out/bin/gn"
    install -Dm644 LICENSE "$out/share/licenses/gn/LICENSE"
    runHook postInstall
  '';
  meta = {
    description = "GN meta-build system at the exact revision required by Dart";
    homepage = "https://gn.googlesource.com/gn/";
    license = lib.licenses.bsd3;
    platforms = [ "x86_64-linux" ];
    mainProgram = "gn";
  };
  passthru = {
    tvp.deps = {
      inherit python ninja patchelf;
    };
    tvp.cc = stdenv.cc;
    tvp.revision = revision;
    tests = mkTests finalAttrs.finalPackage;
  };
})

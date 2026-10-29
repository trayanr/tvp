{
  lib,
  stdenv,
  fetchurl,
  unzip,
  patchelf,
  dynamicLinker,
  channel,
  version,
  sha256,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "dart-bootstrap";
  inherit version;
  src = fetchurl {
    url = "https://storage.googleapis.com/dart-archive/channels/${channel}/release/${version}/sdk/dartsdk-linux-x64-release.zip";
    inherit sha256;
  };
  nativeBuildInputs = [
    unzip
    patchelf
  ];
  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;
  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -a . "$out/"
    while IFS= read -r -d "" binary; do
      if isELF "$binary"; then
        chmod u+w "$binary"
        if patchelf --print-interpreter "$binary" >/dev/null 2>&1; then
          patchelf --set-interpreter '${stdenv.cc.libc}/${dynamicLinker}' "$binary"
        fi
        old_rpath=$(patchelf --print-rpath "$binary")
        patchelf --set-rpath "$old_rpath:${stdenv.cc.libc}/lib:${lib.getLib stdenv.cc.cc}/lib" "$binary"
      fi
    done < <(find "$out/bin" -type f -print0)
    runHook postInstall
  '';
  meta = {
    description = "Explicit upstream Dart bootstrap SDK distribution";
    homepage = "https://dart.dev/";
    license = lib.licenses.bsd3;
    sourceProvenance = [
      lib.sourceTypes.binaryNativeCode
      lib.sourceTypes.binaryBytecode
    ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "dart";
  };
  passthru = {
    tvp.deps = {
      inherit unzip patchelf;
    };
    tests = mkTests finalAttrs.finalPackage;
  };
})

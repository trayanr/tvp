{
  lib,
  stdenv,
  fetchurl,
  patchelf,
  zlib,
  alsa,
  fontconfig,
  dynamicLinker,
  buildNumber,
  version,
  sha256,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "jdk-bootstrap";
  inherit version;
  src = fetchurl {
    url = "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-${version}%2B${buildNumber}/OpenJDK21U-jdk_x64_linux_hotspot_${version}_${buildNumber}.tar.gz";
    inherit sha256;
  };
  nativeBuildInputs = [ patchelf ];
  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;
  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -a . "$out/"
    # Only the headless bootstrap interface is supported. X11's toolkit is
    # outside this seed's dependency graph.
    rm -f "$out/lib/libawt_xawt.so"
    while IFS= read -r -d "" binary; do
      if isELF "$binary"; then
        chmod u+w "$binary"
        if patchelf --print-interpreter "$binary" >/dev/null 2>&1; then
          patchelf --set-interpreter '${stdenv.cc.libc}/${dynamicLinker}' "$binary"
        fi
        old_rpath=$(patchelf --print-rpath "$binary")
        patchelf --set-rpath "$old_rpath:$out/lib:$out/lib/server:${stdenv.cc.libc}/lib:${lib.getLib stdenv.cc.cc}/lib:${zlib}/lib:${alsa}/lib:${fontconfig}/lib" "$binary"
      fi
    done < <(find "$out/bin" "$out/lib" -type f -print0)
    runHook postInstall
  '';
  meta = {
    description = "Explicit headless Temurin boot JDK seed";
    homepage = "https://adoptium.net/";
    license = lib.licenses.gpl2Classpath;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "java";
  };
  passthru = {
    tvp.deps = {
      inherit
        patchelf
        zlib
        alsa
        fontconfig
        ;
    };
    tvp.features.gui = false;
    tests = mkTests finalAttrs.finalPackage;
  };
})

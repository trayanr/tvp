{
  lib,
  stdenv,
  fetchurl,
  unzip,
  patchelf,
  bash,
  dynamicLinker,
  url,
  sdkPath,
  packageMetadata,
  version,
  sha256,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "android-platform-tools";
  inherit version;
  src = fetchurl { inherit url sha256; };
  nativeBuildInputs = [
    unzip
    patchelf
  ];
  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;
  dontPatchShebangs = true;
  installPhase = ''
    runHook preInstall
    component="$out/libexec/android-sdk/${sdkPath}"
    mkdir -p "$component" "$out/bin"
    cp -a . "$component/"
    chmod -R u+w "$component"
    cp ${packageMetadata} "$component/package.xml"
    cp ${../android-sdk-license.txt} "$component/TVP-SDK-LICENSE.txt"

    hostDynamicLinker='${stdenv.cc.libc}/${dynamicLinker}'
    hostRuntimePaths='${stdenv.cc.libc}/lib:${lib.getLib stdenv.cc.cc}/lib'
    source ${../patch-host-tools.sh}
    patchHostTools "$component" "$component/lib64"

    for tool in adb fastboot etc1tool hprof-conv sqlite3 make_f2fs make_f2fs_casefold mke2fs; do ln -s "$component/$tool" "$out/bin/"; done
    runHook postInstall
  '';
  meta = {
    description = "Pinned Android SDK component: android-platform-tools";
    homepage = "https://developer.android.com/tools";
    license = lib.licenses.unfree;
    sourceProvenance = [
      lib.sourceTypes.binaryNativeCode
      lib.sourceTypes.binaryBytecode
    ];
    platforms = [ "x86_64-linux" ];
  };
  passthru = {
    tvp.deps = {
      inherit unzip patchelf bash;
    };
    tvp.android = {
      inherit sdkPath;
      componentPath = "libexec/android-sdk/${sdkPath}";
    };
    tests = mkTests finalAttrs.finalPackage;
  };
})

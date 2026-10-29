{
  lib,
  stdenv,
  fetchurl,
  unzip,
  patchelf,
  bash,
  jdk,
  dynamicLinker,
  url,
  sdkPath,
  packageMetadata,
  version,
  sha256,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "android-build-tools";
  inherit version;
  src = fetchurl { inherit url sha256; };
  nativeBuildInputs = [
    unzip
    patchelf
    jdk
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
    patchShebangs "$component/apksigner" "$component/d8" "$component/lld"
    substituteInPlace "$component/apksigner" "$component/d8" --replace-fail /bin/ls ls
    hostDynamicLinker='${stdenv.cc.libc}/${dynamicLinker}'
    hostRuntimePaths='${stdenv.cc.libc}/lib:${lib.getLib stdenv.cc.cc}/lib'
    source ${../patch-host-tools.sh}
    patchHostTools "$component" "$component/lib64" "$component/lld-bin"

    # Keep the upstream script basename and directory layout intact.
    for script in "$component"/bin/* "$component"/d8 "$component"/apksigner; do
      if test -f "$script" && head -c2 "$script" | grep -q '#!'; then
        sed -i '2i export JAVA_HOME=${jdk}\nexport PATH=${jdk}/bin:$PATH' "$script"
      fi
    done

    for tool in aapt aapt2 aidl apksigner d8 dexdump zipalign; do ln -s "$component/$tool" "$out/bin/"; done
    runHook postInstall
  '';
  meta = {
    description = "Pinned Android SDK component: android-build-tools";
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
      inherit
        unzip
        patchelf
        bash
        jdk
        ;
    };
    tvp.android = {
      inherit sdkPath;
      componentPath = "libexec/android-sdk/${sdkPath}";
    };
    tests = mkTests finalAttrs.finalPackage;
  };
})

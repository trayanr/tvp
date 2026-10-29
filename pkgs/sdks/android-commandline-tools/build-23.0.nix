{
  lib,
  stdenv,
  fetchurl,
  unzip,
  androidCli,
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
  pname = "android-commandline-tools";
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
    rm "$component/bin/android"
    ln -s ${androidCli}/bin/android "$component/bin/android"
    patchShebangs "$component/bin"
    hostDynamicLinker='${stdenv.cc.libc}/${dynamicLinker}'
    hostRuntimePaths='${stdenv.cc.libc}/lib:${lib.getLib stdenv.cc.cc}/lib'
    source ${../patch-host-tools.sh}
    patchHostTools "$component/bin"

    # Keep the upstream script basename and directory layout intact.
    for script in "$component"/bin/* "$component"/d8 "$component"/apksigner; do
      if test -f "$script" && head -c2 "$script" | grep -q '#!'; then
        sed -i '2i export JAVA_HOME=${jdk}\nexport PATH=${jdk}/bin:$PATH' "$script"
      fi
    done

    for tool in "$component/bin/"*; do test -x "$tool" && ln -s "$tool" "$out/bin/"; done
    runHook postInstall
  '';
  meta = {
    description = "Pinned Android SDK component: android-commandline-tools";
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
        androidCli
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

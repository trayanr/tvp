{
  lib,
  stdenv,
  fetchurl,
  unzip,
  patchelf,
  bash,
  zlib,
  gnumake,
  dynamicLinker,
  url,
  sdkPath,
  packageMetadata,
  version,
  sha256,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "android-ndk";
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
    host="$component/toolchains/llvm/prebuilt/linux-x86_64"
    rm "$component/prebuilt/linux-x86_64/bin/make"
    ln -s ${gnumake}/bin/make "$component/prebuilt/linux-x86_64/bin/make"
    patchShebangs "$host/bin" "$component/ndk-build" "$component/build" "$component/prebuilt/linux-x86_64/bin"
    hostDynamicLinker='${stdenv.cc.libc}/${dynamicLinker}'
    hostRuntimePaths='${stdenv.cc.libc}/lib:${lib.getLib stdenv.cc.cc}/lib:${zlib}/lib'
    source ${../patch-host-tools.sh}
    patchHostTools "$host/bin" "$host/lib" "$host/lib/x86_64-unknown-linux-gnu" "$component/prebuilt/linux-x86_64/bin"
    patchHostTools "$host/python3/bin" "$host/python3/lib"
    while IFS= read -r directory; do patchHostTools "$directory"; done < <(find "$host/python3/lib" -type d -name lib-dynload)
    for directory in "$host"/lib/python*/site-packages/lldb; do patchHostTools "$directory"; done
    for tool in "$host/bin/"*; do test -x "$tool" && ln -s "$tool" "$out/bin/"; done
    cat > "$out/bin/ndk-build" <<EOF
    #!${bash}/bin/bash
    exec "$component/ndk-build" "\$@"
    EOF
    chmod +x "$out/bin/ndk-build"
    runHook postInstall
  '';
  postFixup = ''
    # Check all target sysroot and compiler runtime bytes against the archive.
    diff -qr toolchains/llvm/prebuilt/linux-x86_64/sysroot "$out/libexec/android-sdk/${sdkPath}/toolchains/llvm/prebuilt/linux-x86_64/sysroot"
    diff -qr toolchains/llvm/prebuilt/linux-x86_64/lib/clang "$out/libexec/android-sdk/${sdkPath}/toolchains/llvm/prebuilt/linux-x86_64/lib/clang"
  '';
  meta = {
    description = "Pinned Android SDK component: android-ndk";
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
        zlib
        gnumake
        ;
    };
    tvp.android = {
      inherit sdkPath;
      componentPath = "libexec/android-sdk/${sdkPath}";
    };
    tests = mkTests finalAttrs.finalPackage;
  };
})

{
  lib,
  stdenv,
  fetchurl,
  unzip,
  url,
  sdkPath,
  apiLevel,
  packageMetadata,
  version,
  sha256,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "android-platform";
  inherit version;
  src = fetchurl { inherit url sha256; };
  nativeBuildInputs = [ unzip ];
  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;
  dontPatchShebangs = true;
  installPhase = ''
    mkdir -p "$out/libexec/android-sdk/${sdkPath}"
    cp -a . "$out/libexec/android-sdk/${sdkPath}/"
    cp ${packageMetadata} "$out/libexec/android-sdk/${sdkPath}/package.xml"
    cp ${../android-sdk-license.txt} "$out/libexec/android-sdk/${sdkPath}/TVP-SDK-LICENSE.txt"
  '';
  meta = {
    description = "Android platform API ${apiLevel}, revision preserved in package version";
    homepage = "https://developer.android.com/tools";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryBytecode ];
    platforms = [ "x86_64-linux" ];
  };
  passthru = {
    tvp.deps = {
      inherit unzip;
    };
    tvp.android = {
      inherit sdkPath apiLevel;
      componentPath = "libexec/android-sdk/${sdkPath}";
    };
    tests = mkTests finalAttrs.finalPackage;
  };
})

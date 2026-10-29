{
  lib,
  stdenv,
  fetchurl,
  patchelf,
  dynamicLinker,
  version,
  sha256,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "android-cli";
  inherit version;
  src = fetchurl {
    url = "https://dl.google.com/android/cli/${version}/linux_x86_64/android-cli";
    inherit sha256;
  };
  nativeBuildInputs = [ patchelf ];
  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;
  installPhase = ''
    mkdir -p "$out/bin" "$out/share/licenses/android-cli"
    install -m755 "$src" "$out/bin/android"
    cp ${../android-sdk-license.txt} "$out/share/licenses/android-cli/SDK-LICENSE.txt"
    patchelf --set-interpreter '${stdenv.cc.libc}/${dynamicLinker}' --set-rpath '${stdenv.cc.libc}/lib' "$out/bin/android"
    patchelf --shrink-rpath "$out/bin/android"
  '';
  meta = {
    description = "Pinned native Android CLI without the auto-downloading launcher";
    homepage = "https://developer.android.com/tools/agents/android-cli";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "android";
  };
  passthru = {
    tvp.deps = {
      inherit patchelf;
    };
    tests = mkTests finalAttrs.finalPackage;
  };
})

# Native x86_64 Linux userspace API headers, not a kernel build.
{
  lib,
  stdenv,
  platforms,
  fetchurl,
  perl,
  version,
  sha256,
  mkTests,
}:
let
  platform = platforms.forStdenv stdenv;
in
assert platform.isNative;
stdenv.mkDerivation (finalAttrs: {
  pname = "linux-headers";
  inherit version;
  src = fetchurl {
    url = "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${version}.tar.xz";
    inherit sha256;
  };
  nativeBuildInputs = [ perl ];
  dontConfigure = true;
  enableParallelBuilding = true;
  makeFlags = [
    "ARCH=${platform.linuxHeadersArch}"
    "SHELL=bash"
  ];
  buildPhase = ''
    runHook preBuild
    make -j"$NIX_BUILD_CORES" headers "''${makeFlagsArray[@]}" $makeFlags
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -r usr/include "$out/"
    find "$out" -type f ! -name '*.h' -delete
    runHook postInstall
  '';
  meta = {
    description = "Linux userspace API headers";
    homepage = "https://kernel.org/";
    license = lib.licenses.gpl2Only;
    platforms = [ "x86_64-linux" ];
  };
  passthru = {
    inherit platform;
    tvp.deps = {
      inherit perl;
    };
    tvp.cc = stdenv.cc;
    tests = mkTests finalAttrs.finalPackage;
  };
})

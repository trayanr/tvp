{
  lib,
  stdenv,
  fetchurl,
  patchelf,
  version,
  sha256,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "gperf";
  inherit version;
  src = fetchurl {
    url = "https://ftpmirror.gnu.org/gperf/gperf-${version}.tar.gz";
    inherit sha256;
  };
  nativeBuildInputs = [ patchelf ];
  enableParallelBuilding = true;
  doCheck = true;
  meta = {
    description = "GNU perfect hash function generator";
    homepage = "https://www.gnu.org/software/gperf/";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
    mainProgram = "gperf";
  };
  passthru = {
    tvp.deps = {
      inherit patchelf;
    };
    tvp.cc = stdenv.cc;
    tests = mkTests finalAttrs.finalPackage;
  };
})

# Serves 0.19 onwards; retain upstream's shared/static, app, pointer and patch defaults.
{
  lib,
  stdenv,
  fetchurl,
  cmake,
  version,
  sha256,
  tagDate,
  patches,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "json-c";
  inherit version patches;
  src = fetchurl {
    url = "https://github.com/json-c/json-c/releases/download/json-c-${version}-${tagDate}/json-c-${version}.tar.gz";
    inherit sha256;
  };
  nativeBuildInputs = [ cmake ];
  postPatch = ''
    patchShebangs tests
  '';
  enableParallelBuilding = true;
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    ctest --output-on-failure -j "$NIX_BUILD_CORES"
    runHook postCheck
  '';
  meta = {
    description = "JSON parser, serializer and reference-counted object library in C";
    homepage = "https://github.com/json-c/json-c";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
  passthru = {
    tvp.deps = {
      inherit cmake;
    };
    tvp.cc = stdenv.cc;
    tests = mkTests finalAttrs.finalPackage;
  };
})

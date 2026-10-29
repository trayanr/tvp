{
  lib,
  stdenv,
  fetchurl,
  version,
  sha256,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "patchelf";
  inherit version;
  src = fetchurl {
    url = "https://github.com/NixOS/patchelf/releases/download/${version}/patchelf-${version}.tar.bz2";
    inherit sha256;
  };
  enableParallelBuilding = true;
  # The base supplies a pinned patchelf; never execute the file being modified.
  meta = {
    description = "Modify ELF interpreters, dependencies and runtime search paths";
    homepage = "https://github.com/NixOS/patchelf";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
    mainProgram = "patchelf";
  };
  passthru = {
    tvp.deps = { };
    tvp.cc = stdenv.cc;
    tests = mkTests finalAttrs.finalPackage;
  };
})

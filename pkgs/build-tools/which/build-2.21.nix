{
  lib,
  stdenv,
  fetchurl,
  version,
  sha256,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "which";
  inherit version;
  src = fetchurl {
    url = "https://mirrors.kernel.org/gnu/which/which-${version}.tar.gz";
    inherit sha256;
  };
  enableParallelBuilding = true;
  meta = {
    description = "GNU command path lookup";
    homepage = "https://www.gnu.org/software/which/";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.unix;
    mainProgram = "which";
  };
  passthru = {
    tvp.deps = { };
    tests = mkTests finalAttrs.finalPackage;
  };
})

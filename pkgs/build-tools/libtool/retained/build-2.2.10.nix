# Libtool 2.2 ships libltdl/config/ltmain.sh directly and predates the
# tool-default templates used by the 2.4+ recipe.
{
  lib,
  stdenv,
  fetchurl,
  autoconf,
  automake,
  m4,
  file,
  version,
  sha256,
  patches ? [ ],
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "libtool";
  inherit version patches;
  src = fetchurl {
    url = "https://mirrors.kernel.org/gnu/libtool/libtool-${version}.tar.gz";
    inherit sha256;
  };
  nativeBuildInputs = [
    autoconf
    automake
    m4
    file
  ];
  propagatedBuildInputs = [
    autoconf
    automake
    m4
    file
  ];
  # This release ships ltmain.sh directly; there is no ltmain.in template
  # to regenerate and no runtime Autoconf/Automake defaults to substitute.
  postPatch = ''patchShebangs libtoolize.in'';
  configureFlags = [
    "M4=${m4}/bin/m4"
    "FILECMD=${file}/bin/file"
  ];
  enableParallelBuilding = true;
  meta = {
    description = "GNU portable library build tools and libltdl loader library";
    homepage = "https://www.gnu.org/software/libtool/";
    license = [
      lib.licenses.gpl2Plus
      lib.licenses.lgpl2Plus
    ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "libtool";
  };
  passthru = {
    tvp.deps = {
      inherit
        autoconf
        automake
        m4
        file
        ;
    };
    tvp.features.cxxDependencyTracking = true;
    tvp.features.acLibtool = true;
    tvp.features.ltdl = true;
    tvp.features.ltInit = true;
    tvp.cc = stdenv.cc;
    tests = mkTests finalAttrs.finalPackage;
  };
})

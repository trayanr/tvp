# Libtool 2.4 onward generates ltmain.sh from build-aux/ltmain.in and
# carries Autoconf/Automake defaults that need declared store paths.
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
    url = "https://mirrors.kernel.org/gnu/libtool/libtool-${version}.tar.xz";
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
  postPatch = ''
    for script in libtoolize.in build-aux/ltmain.in; do
      substituteInPlace "$script" \
        --replace-fail '@TVP_AUTOCONF@' '${autoconf}/bin/autoconf' \
        --replace-fail '@TVP_AUTOMAKE@' '${automake}/bin/automake'
    done
    patchShebangs libtoolize.in
  '';
  preBuild = ''
    make build-aux/ltmain.sh
    # Interpreter/command path changes do not change the shipped manual pages.
    touch -r build-aux/ltmain.sh doc/libtool.1
    touch -r libtoolize.in doc/libtoolize.1
  '';
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

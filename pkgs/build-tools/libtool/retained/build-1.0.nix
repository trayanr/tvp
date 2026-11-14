# Libtool 1.0 through 1.4 require environment tool bindings rather than
# configure VAR=value arguments. Their platform scripts predate x86_64;
# a separate Automake pin supplies config.guess/sub independently of the
# consumer-tool pins, which can predate modern platform recognition.
{
  lib,
  stdenv,
  fetchurl,
  autoconf,
  automake,
  platformAutomake,
  m4,
  file,
  version,
  sha256,
  cStandard ? null,
  testFeatures ? { },
  license ? [
    lib.licenses.gpl2Plus
    lib.licenses.lgpl2Plus
  ],
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
  # These archives ship ltmain.sh directly. Avoid regeneration and preserve
  # the original command semantics while adapting interpreter/platform paths.
  postPatch = ''
    patchShebangs libtoolize.in
    # The shipped platform scripts predate x86_64. Use the declared GNU
    # Automake scripts for native platform recognition.
    cp ${platformAutomake}/share/automake-${platformAutomake.version}/config.{guess,sub} .
  '';
  # These configure scripts treat VAR=value arguments as host names.
  preConfigure =
    lib.optionalString (cStandard != null) ''
      export CFLAGS="''${CFLAGS:--g -O2} -std=${cStandard}"
    ''
    + ''
      export M4=${m4}/bin/m4
      export FILECMD=${file}/bin/file
    '';
  enableParallelBuilding = true;
  meta = {
    description = "GNU portable library build tools";
    homepage = "https://www.gnu.org/software/libtool/";
    inherit license;
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
    tvp.features = {
      consumerCStandard = cStandard;
      cxxDependencyTracking = false;
      acLibtool = true;
      ltdl = true;
      ltInit = false;
    } // testFeatures;
    tvp.buildDeps = {
      inherit platformAutomake;
    };
    tvp.cc = stdenv.cc;
    tests = mkTests finalAttrs.finalPackage;
  };
})

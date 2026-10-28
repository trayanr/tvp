# Serves 13.3 onwards: native x86_64 Linux C/C++ with GCC's stage comparison.
{
  lib,
  stdenv,
  platforms,
  fetchurl,
  binutils,
  gmp,
  mpfr,
  mpc,
  isl,
  zlib,
  zstd,
  libxcrypt,
  perl,
  glibc,
  texinfo,
  which,
  version,
  sha256,
  patches ? [ ],
  bootstrap ? true,
  hardeningDisable ? [ ],
  mkTests,
}:
let
  platform = platforms.forStdenv stdenv;
  crtFlags = "-B${glibc}/lib/ -isystem ${lib.getDev glibc}/include -I${lib.getDev zlib}/include -I${lib.getDev zstd}/include -I${lib.getDev libxcrypt}/include";
  runtimeFlags = lib.concatStringsSep " " (
    [
      "-L${glibc}/lib"
      "-Wl,-dynamic-linker,${glibc}/${platform.dynamicLinker}"
      "-Wl,-rpath,${placeholder "out"}/lib"
    ]
    ++ map (p: "-L${lib.getLib p}/lib -Wl,-rpath,${lib.getLib p}/lib") [
      glibc
      gmp
      mpfr
      mpc
      isl
      zlib
      zstd
      libxcrypt
    ]
  );
in
assert platform.isNative;
stdenv.mkDerivation (finalAttrs: {
  pname = "gcc";
  inherit version patches hardeningDisable;
  src = fetchurl {
    url = "https://mirrors.kernel.org/gnu/gcc/gcc-${version}/gcc-${version}.tar.xz";
    inherit sha256;
  };
  nativeBuildInputs = [
    binutils
    perl
    texinfo
    which
  ];
  buildInputs = [
    gmp
    mpfr
    mpc
    isl
    zlib
    zstd
    libxcrypt
  ];
  enableParallelBuilding = true;
  preConfigure = ''
    mkdir -p ../build
    cd ../build
    configureScript="$NIX_BUILD_TOP/$sourceRoot/configure"
  '';
  configureFlags = [
    "--enable-languages=c,c++"
    "--disable-multilib"
    "--enable-checking=release"
    "--with-system-zlib"
    "--with-gmp=${lib.getDev gmp}"
    "--with-mpfr=${lib.getDev mpfr}"
    "--with-mpc=${lib.getDev mpc}"
    "--with-isl=${lib.getDev isl}"
    "--with-zstd=${lib.getDev zstd}"
    "--with-native-system-header-dir=${lib.getDev glibc}/include"
    "--with-build-sysroot=/"
    "--with-as=${binutils}/bin/as"
    "--with-ld=${binutils}/bin/ld"
    "--libdir=${placeholder "out"}/lib"
    (if bootstrap then "--enable-bootstrap" else "--disable-bootstrap")
  ];
  preBuild = ''
    makeFlagsArray+=(
    "BOOT_CFLAGS=-O2 ${crtFlags} ${runtimeFlags}"
    "BOOT_LDFLAGS=${runtimeFlags}"
    "CFLAGS_FOR_TARGET=-O2 ${crtFlags} ${runtimeFlags}"
    "CXXFLAGS_FOR_TARGET=-O2 ${crtFlags} ${runtimeFlags}"
    "FLAGS_FOR_TARGET=${crtFlags} ${runtimeFlags}"
    "LDFLAGS_FOR_TARGET=${runtimeFlags}"
    "SYSTEM_HEADER_DIR=${lib.getDev glibc}/include"
    "NATIVE_SYSTEM_HEADER_DIR=${lib.getDev glibc}/include"
    "LIMITS_H_TEST=true"
    )
  '';
  postInstall = ''
    if [ -d "$out/lib64" ] && [ ! -L "$out/lib64" ]; then
      cp -a "$out/lib64/." "$out/lib/"
      rm -rf "$out/lib64"
      ln -s lib "$out/lib64"
    fi
    ln -sf gcc "$out/bin/cc"
    ln -sf g++ "$out/bin/c++"
  '';
  meta = {
    description = "GNU C/C++ compiler, unwrapped, with an explicit bootstrap toolchain";
    homepage = "https://gcc.gnu.org/";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
    priority = 10;
  };
  passthru = {
    inherit platform;
    tvp.deps = {
      inherit
        binutils
        gmp
        mpfr
        mpc
        isl
        zlib
        zstd
        libxcrypt
        perl
        glibc
        texinfo
        which
        ;
    };
    tvp.bootstrap = bootstrap;
    tests = mkTests finalAttrs.finalPackage;
  };
})

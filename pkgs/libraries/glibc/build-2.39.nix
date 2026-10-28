# Upstream glibc release with store layout adaptations only.
{
  lib,
  stdenv,
  fetchurl,
  gcc,
  binutils,
  linuxHeaders,
  bison,
  python3Minimal,
  perl,
  version,
  sha256,
  patches ? [ ],
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "glibc";
  inherit version patches;
  # Scripts can be rebound to an owned shell after libc bootstraps that shell.
  outputs = [
    "out"
    "bin"
  ];
  setOutputFlags = false;
  propagatedBuildOutputs = [ ];
  src = fetchurl {
    url = "https://mirrors.kernel.org/gnu/glibc/glibc-${version}.tar.xz";
    inherit sha256;
  };
  nativeBuildInputs = [
    binutils
    bison
    python3Minimal
    perl
  ];
  enableParallelBuilding = true;
  hardeningDisable = [ "all" ];
  # glibc constructs its own include/link environment. The bootstrap wrapper's
  # libc must not leak into libc itself.
  preConfigure = ''
    substituteInPlace elf/rtld.c \
      --replace-fail '"/etc/ld.so.preload"' '"${placeholder "out"}/etc/ld.so.preload"'
    echo 'LDFLAGS-nscd += -static-libgcc' >> nscd/Makefile
    export BUILD_CC="${stdenv.cc}/bin/cc"
    export CC="${gcc}/bin/gcc -B${binutils}/bin/ -B${gcc.tvp.deps.glibc}/lib/"
    export CXX="${gcc}/bin/g++ -B${binutils}/bin/ -B${gcc.tvp.deps.glibc}/lib/"
    export AR=${binutils}/bin/ar
    export AS=${binutils}/bin/as
    export LD=${binutils}/bin/ld
    export NM=${binutils}/bin/nm
    export OBJCOPY=${binutils}/bin/objcopy
    export OBJDUMP=${binutils}/bin/objdump
    export RANLIB=${binutils}/bin/ranlib
    export CFLAGS=-O2
    export CXXFLAGS=-O2
    unset CPATH C_INCLUDE_PATH CPLUS_INCLUDE_PATH LIBRARY_PATH
    mkdir -p ../build
    cd ../build
    configureScript="$NIX_BUILD_TOP/$sourceRoot/configure"
  '';
  configureFlags = [
    "--with-headers=${linuxHeaders}/include"
    "--enable-kernel=3.10.0"
    "--disable-werror"
    "--enable-stack-protector=strong"
    "--enable-bind-now"
    "--enable-static-pie"
  ];
  makeFlags = [ "OBJCOPY=${binutils}/bin/objcopy" ];
  installFlags = [ "sysconfdir=$(out)/etc" ];
  postInstall = ''
    # Upstream's x86_64 ldd loader list uses lib64, while this store prefix
    # installs its native libraries in lib. Preserve the ABI directory alias.
    ln -sT lib "$out/lib64"
    # C.UTF-8 is part of the build environment contract. Other locale data can
    # be generated from this same upstream release with localedef.
    mkdir -p "$out/lib/locale"
    I18NPATH="$NIX_BUILD_TOP/$sourceRoot/localedata" \
      "$out/bin/localedef" --no-archive -i C -f UTF-8 "$out/lib/locale/C.utf8"
    # glibc's public headers include Linux UAPI headers.
    cp -rs ${linuxHeaders}/include/* "$out/include/"
    moveToOutput bin "$bin"
    moveToOutput sbin "$bin"
  '';
  meta = {
    description = "GNU C Library";
    homepage = "https://www.gnu.org/software/libc/";
    license = lib.licenses.lgpl2Plus;
    platforms = [ "x86_64-linux" ];
  };
  passthru = {
    mkTools = args: import ./tools.nix ({ glibc = finalAttrs.finalPackage; } // args);
    tvp.deps = {
      inherit
        gcc
        binutils
        linuxHeaders
        bison
        python3Minimal
        perl
        ;
    };
    tests = mkTests finalAttrs.finalPackage;
  };
})

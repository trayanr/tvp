{
  lib,
  stdenv,
  fetchurl,
  bootJdk,
  bash,
  autoconf,
  zip,
  unzip,
  file,
  pkg-config,
  patchelf,
  zlib,
  alsa,
  freetype,
  fontconfig,
  libcups,
  xorgproto,
  libx11,
  libxext,
  libxrender,
  libxtst,
  libxrandr,
  libxt,

  dynamicLinker,
  buildNumber,
  version,
  sha256,
  patches,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "jdk";
  inherit version patches;
  src = fetchurl {
    url = "https://github.com/openjdk/jdk21u/archive/refs/tags/jdk-${version}-ga.tar.gz";
    inherit sha256;
  };
  nativeBuildInputs = [
    bootJdk
    autoconf
    zip
    unzip
    file
    pkg-config
    patchelf
  ];
  buildInputs = [
    xorgproto
    libx11
    libxext
    libxrender
    libxtst
    libxrandr
    libxt

    zlib
    alsa
    freetype
    fontconfig
    libcups
  ];
  env.LANG = "C.UTF-8";
  postPatch = ''
    substituteInPlace src/java.base/unix/native/libjava/childproc.c --replace-fail '@TVP_SHELL@' '${bash}/bin/bash'
    substituteInPlace src/java.desktop/unix/native/common/awt/fontpath.c --replace-fail '@TVP_FONTCONFIG@' '${fontconfig}/lib/libfontconfig.so'
  '';
  configurePhase = ''
    runHook preConfigure
    export CC='${stdenv.cc}/bin/cc' CXX='${stdenv.cc}/bin/c++'
    ${bash}/bin/bash configure \
      --prefix="$out" --with-boot-jdk='${bootJdk}' \
      --x-includes='${libx11}/include' --x-libraries='${libx11}/lib' \
      --with-debug-level=release --with-jvm-variants=server --enable-headless-only \
      --with-freetype=system --with-freetype-include='${freetype}/include/freetype2' --with-freetype-lib='${freetype}/lib' \
      --with-fontconfig='${fontconfig}' --with-cups='${libcups}' --with-alsa='${alsa}' --with-zlib=system \
      --with-version-pre= --with-version-opt= --with-version-build='${buildNumber}' \
      --with-native-debug-symbols=none --with-jobs="$NIX_BUILD_CORES" \
      --disable-warnings-as-errors
    runHook postConfigure
  '';
  buildPhase = ''
    runHook preBuild
    make images
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -a build/*/images/jdk/. "$out/"
    while IFS= read -r -d "" binary; do
      if isELF "$binary" && patchelf --print-interpreter "$binary" >/dev/null 2>&1; then
        patchelf --set-interpreter '${stdenv.cc.libc}/${dynamicLinker}' "$binary"
      fi
    done < <(find "$out/bin" "$out/lib" -type f -print0)
    runHook postInstall
  '';
  meta = {
    description = "Source-built headless OpenJDK development kit";
    homepage = "https://openjdk.org/";
    license = lib.licenses.gpl2Classpath;
    platforms = [ "x86_64-linux" ];
    mainProgram = "java";
  };
  passthru = {
    tvp.deps = {
      inherit
        bootJdk
        bash
        autoconf
        zip
        unzip
        file
        pkg-config
        patchelf
        zlib
        alsa
        freetype
        fontconfig
        libcups
        xorgproto
        libx11
        libxext
        libxrender
        libxtst
        libxrandr
        libxt
        ;
    };
    tvp.cc = stdenv.cc;
    tvp.features.gui = false;
    tests = mkTests finalAttrs.finalPackage;
  };
})

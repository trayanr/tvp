{
  lib,
  stdenv,
  fetchurl,
  bash,
  openssl,
  zlib,
  bzip2,
  xz,
  zstd,
  pkg-config,
  version,
  sha256,
  patches,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "cmake";
  inherit version patches;
  src = fetchurl {
    url = "https://github.com/Kitware/CMake/releases/download/v${version}/cmake-${version}.tar.gz";
    inherit sha256;
  };
  nativeBuildInputs = [ pkg-config ];
  buildInputs = [
    openssl
    zlib
    bzip2
    xz
    zstd
  ];
  postPatch = ''
    patchShebangs bootstrap
    substituteInPlace Source/cmLocalUnixMakefileGenerator3.cxx Source/cmExecProgramCommand.cxx \
      --replace-fail '@TVP_SHELL@' '${bash}/bin/bash'
  '';
  configurePhase = ''
    runHook preConfigure
    ./bootstrap --prefix="$out" --parallel="$NIX_BUILD_CORES" --no-system-libs -- \
      -DBUILD_TESTING=OFF \
      -DCMAKE_PREFIX_PATH='${
        lib.concatStringsSep ";" [
          stdenv.cc.libc
          openssl
          zlib
          bzip2
          xz
          zstd
        ]
      }' \
      -DCMAKE_USE_OPENSSL=ON -DOPENSSL_ROOT_DIR=${openssl} \
      -DCMAKE_USE_SYSTEM_ZLIB=ON -DCMAKE_USE_SYSTEM_BZIP2=ON \
      -DCMAKE_USE_SYSTEM_LIBLZMA=ON -DCMAKE_USE_SYSTEM_ZSTD=ON
    runHook postConfigure
  '';
  enableParallelBuilding = true;
  postInstall = ''
    mkdir -p "$out/nix-support"
    cp ${./setup-hook.sh} "$out/nix-support/setup-hook"
  '';
  meta = {
    description = "Cross-platform build-system generator, CTest and CPack";
    homepage = "https://cmake.org/";
    license = lib.licenses.bsd3;
    platforms = [ "x86_64-linux" ];
    mainProgram = "cmake";
  };
  passthru = {
    tvp.deps = {
      inherit
        bash
        openssl
        zlib
        bzip2
        xz
        zstd
        pkg-config
        ;
    };
    tvp.cc = stdenv.cc;
    tests = mkTests finalAttrs.finalPackage;
  };
})

# Native LLVM, Clang and LLD built from the complete upstream source release.
{
  lib,
  stdenv,
  fetchurl,
  bash,
  python,
  cmake,
  ninja,
  pkg-config,
  patchelf,
  zlib,
  zstd,
  libffi,
  libxml2,
  dynamicLinker,
  version,
  sha256,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "llvm";
  inherit version;
  src = fetchurl {
    url = "https://github.com/llvm/llvm-project/releases/download/llvmorg-${version}/llvm-project-${version}.src.tar.xz";
    inherit sha256;
  };
  nativeBuildInputs = [
    cmake
    ninja
    python
    pkg-config
    patchelf
  ];
  buildInputs = [
    zlib
    zstd
    libffi
    libxml2
  ];
  cmakeDir = "../llvm";
  cmakeFlags = [
    "-DLLVM_ENABLE_PROJECTS=clang;lld"
    "-DLLVM_TARGETS_TO_BUILD=all"
    "-DLLVM_BUILD_LLVM_DYLIB=ON"
    "-DLLVM_LINK_LLVM_DYLIB=ON"
    "-DCLANG_LINK_CLANG_DYLIB=ON"
    "-DLLVM_ENABLE_RTTI=ON"
    "-DLLVM_ENABLE_ZLIB=FORCE_ON"
    "-DLLVM_ENABLE_ZSTD=FORCE_ON"
    "-DLLVM_ENABLE_LIBXML2=FORCE_ON"
    "-DLLVM_ENABLE_FFI=FORCE_ON"
    "-DLLVM_ENABLE_LIBEDIT=OFF"
    "-DLLVM_ENABLE_LIBPFM=OFF"
    "-DLLVM_ENABLE_Z3_SOLVER=OFF"
    "-DLLVM_INCLUDE_DOCS=OFF"
    "-DLLVM_INCLUDE_TESTS=ON"
    "-DLLVM_INSTALL_UTILS=ON"
    "-DCLANG_DEFAULT_CXX_STDLIB=libstdc++"
    "-DCLANG_DEFAULT_RTLIB=libgcc"
    "-DPython3_EXECUTABLE=${python}/bin/python3"
  ];
  enableParallelBuilding = true;
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    ninja FileCheck not
    bin/llvm-lit -sv -j"$NIX_BUILD_CORES" ../llvm/test/Assembler ../llvm/test/Bitcode
    runHook postCheck
  '';
  postInstall = ''
    mkdir -p "$out/nix-support/empty-sysroot"
    gcc_install_dir=$(dirname "$(${stdenv.cc.cc}/bin/gcc -print-libgcc-file-name)")
    clang_real=$(readlink -f "$out/bin/clang")
    clang_name=$(basename "$clang_real")
    mv "$clang_real" "$out/bin/.clang-unwrapped"
    rm -f "$out/bin/clang"
    substitute ${./clang-wrapper.sh} "$out/bin/clang" \
      --subst-var-by bash '${bash}/bin/bash' \
      --subst-var-by gcc '${stdenv.cc.cc}' \
      --subst-var-by gccInstallDir "$gcc_install_dir" \
      --subst-var-by emptyRoot "$out/nix-support/empty-sysroot" \
      --subst-var-by libc '${stdenv.cc.libc}' \
      --subst-var-by bintools '${stdenv.cc.bintools}' \
      --subst-var-by dynamicLinker '${dynamicLinker}' \
      --subst-var-by clang "$out/bin/.clang-unwrapped"
    chmod +x "$out/bin/clang"
    if [ "$clang_name" != clang ]; then ln -s clang "$out/bin/$clang_name"; fi
  '';
  meta = {
    description = "LLVM tools, Clang C/C++ compiler and LLD linker";
    homepage = "https://llvm.org/";
    license = lib.licenses.asl20-llvm;
    platforms = [ "x86_64-linux" ];
    mainProgram = "clang";
  };
  passthru = {
    tvp.deps = {
      inherit
        bash
        python
        cmake
        ninja
        pkg-config
        patchelf
        zlib
        zstd
        libffi
        libxml2
        ;
    };
    tvp.cc = stdenv.cc;
    tvp.dynamicLinker = "${stdenv.cc.libc}/${dynamicLinker}";
    tvp.features = {
      c = true;
      cxx = true;
      lld = true;
      libedit = false;
      perfCounters = false;
      z3 = false;
    };
    tests = mkTests finalAttrs.finalPackage;
  };
})

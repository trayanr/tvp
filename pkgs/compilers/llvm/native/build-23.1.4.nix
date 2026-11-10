# LLVM 23.1.4 begins the owned native procedure. Keep the complete upstream
# profile and Assembler/Bitcode checks; qualification is a separate parent gate.
{
  tvp,
  lib,
  base,
  src,
  version,
  bash,
  coreutils,
  helperPython,
  gnutar,
  xz,
  findutils,
  binutils,
  patchelf,
  python,
  perl,
  cmake,
  ninja,
  pkg-config,
  zlib,
  zstd,
  libffi,
  libxml2,
  rawGCC,
  cxxRuntime,
  gccRuntime,
  libc,
  targetBinutils,
  dynamicLinker,
}@args:
final:
let
  inherit (final)
    base
    src
    version
    bash
    coreutils
    helperPython
    gnutar
    xz
    findutils
    binutils
    patchelf
    python
    perl
    cmake
    ninja
    pkg-config
    zlib
    zstd
    libffi
    libxml2
    rawGCC
    cxxRuntime
    gccRuntime
    libc
    targetBinutils
    dynamicLinker
    ;
  inherit (tvp.builder) steps outputs;
  environment = base.environment final.environment;
  command =
    name: run:
    environment
    // {
      name = "llvm.${name}";
      inherit run;
    };
  elfPaths = [
    "bin"
    "lib"
  ];
in
{
  pname = "llvm";
  inherit (args)
    base
    src
    version
    bash
    coreutils
    helperPython
    gnutar
    xz
    findutils
    binutils
    patchelf
    python
    perl
    cmake
    ninja
    pkg-config
    zlib
    zstd
    libffi
    libxml2
    rawGCC
    cxxRuntime
    gccRuntime
    libc
    targetBinutils
    dynamicLinker
    ;
  environment = {
    tools = [
      bash
      coreutils
      python
      perl
      cmake
      ninja
      pkg-config
    ];
    libraries = [
      zlib
      zstd
      libffi
      libxml2
    ];
  };
  # Build-tool runtime belongs to the base. The installed driver's target is
  # independently selected: public raw GCC and its matching C++/libgcc output,
  # public libc and Binutils. No build closure becomes runtime permission.
  runtime = {
    libraries = final.environment.libraries;
    target = {
      inherit
        rawGCC
        cxxRuntime
        gccRuntime
        libc
        targetBinutils
        ;
    };
    shell = bash;
    python = python;
    perl = perl;
    loader = "${final.runtime.target.libc}/${dynamicLinker}";
  };
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
    "-DZLIB_ROOT=${zlib}"
    "-Dzstd_DIR=${zstd}/lib/cmake/zstd"
    "-DLIBXML2_INCLUDE_DIR=${libxml2}/include/libxml2"
    "-DLIBXML2_LIBRARY=${libxml2}/lib/libxml2.so"
    "-DFFI_INCLUDE_DIR=${libffi}/include"
    "-DFFI_LIBRARY_DIR=${libffi}/lib"
  ];
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = gnutar;
      inherit xz findutils;
    })
    (command "configure" ''
      ${cmake}/bin/cmake -S source/llvm -B build -G Ninja \
        -DCMAKE_MAKE_PROGRAM=${ninja}/bin/ninja -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$out" -DCMAKE_INSTALL_LIBDIR=lib \
        -DCMAKE_C_COMPILER="$CC" -DCMAKE_CXX_COMPILER="$CXX" \
        -DCMAKE_FIND_USE_PACKAGE_REGISTRY=OFF -DCMAKE_FIND_USE_SYSTEM_PACKAGE_REGISTRY=OFF \
        -DCMAKE_PREFIX_PATH=${
          lib.escapeShellArg (
            lib.concatStringsSep ";" (map (p: "${lib.getDev p}") final.environment.libraries)
          )
        } \
        ${lib.escapeShellArgs final.cmakeFlags}
    '')
    (command "build" ''${ninja}/bin/ninja -C build -j"$NIX_BUILD_CORES"'')
    (command "check" ''
      ${ninja}/bin/ninja -C build -j"$NIX_BUILD_CORES" FileCheck not
      ${python}/bin/python3 build/bin/llvm-lit -sv -j"$NIX_BUILD_CORES" source/llvm/test/Assembler source/llvm/test/Bitcode
    '')
    (command "install" ''
      ${ninja}/bin/ninja -C build -j"$NIX_BUILD_CORES" install
      mkdir -p "$out/nix-support"
      cp build/CMakeCache.txt "$out/nix-support/CMakeCache.txt"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (outputs.strip {
      python = helperPython;
      inherit binutils;
      paths = elfPaths;
    })
    (outputs.rpaths {
      python = helperPython;
      inherit binutils patchelf;
      base = final.base;
      paths = elfPaths;
      libraries = final.runtime.libraries;
    })
    (
      (outputs.shebangs {
        python = helperPython;
        paths = [
          "bin"
          "libexec"
        ];
        names = [
          "python"
          "python3"
        ];
        interpreter = "${final.runtime.python}/bin/python3";
      })
      // {
        name = "llvm.python-scripts";
      }
    )
    (
      (outputs.shebangs {
        python = helperPython;
        paths = [
          "bin"
          "libexec"
        ];
        names = [ "perl" ];
        interpreter = "${final.runtime.perl}/bin/perl";
      })
      // {
        name = "llvm.perl-scripts";
      }
    )
    {
      name = "llvm.wrap-target";
      tools = [ helperPython ];
      run = ''${helperPython}/bin/python3 -B ${./install-wrapper.py} "$out" ${./clang-wrapper.sh} ${
        lib.escapeShellArg (
          builtins.toJSON {
            bash = "${final.runtime.shell}/bin/bash";
            gcc = toString final.runtime.target.rawGCC;
            gccRuntime = toString final.runtime.target.gccRuntime;
            cxxRuntime = toString final.runtime.target.cxxRuntime;
            libc = toString final.runtime.target.libc;
            bintools = toString final.runtime.target.targetBinutils;
            loader = final.runtime.loader;
          }
        )
      }'';
    }
    (outputs.checkPaths {
      python = helperPython;
      inherit binutils patchelf;
      paths = elfPaths;
    })
  ];
  tvp.dynamicLinker = final.runtime.loader;
  tvp.features = {
    c = true;
    cxx = true;
    lld = true;
    libedit = false;
    perfCounters = false;
    z3 = false;
  };
  meta = {
    description = "LLVM tools, Clang C/C++ compiler and LLD linker";
    homepage = "https://llvm.org/";
    license = lib.licenses.asl20-llvm;
    platforms = [ "x86_64-linux" ];
    mainProgram = "clang";
  };
}

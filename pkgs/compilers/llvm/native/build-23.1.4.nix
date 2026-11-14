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
  sed,
  grep,
  diffutils,
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
    sed
    grep
    diffutils
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
  artifactName = "${final.pname}-${final.version}";
  finalizer = ./finalize.py;
  rubyFinalizer = ../../../runtimes/ruby/owned/finalize.py;
  archiveFinalizer = ../../../libraries/libxml2/ordinary/finalize.py;
  archiveElfFinalizer = ../../../libraries/libxml2/ordinary/elf.py;
  elfFinalizer = ../../../runtimes/perl/ordinary/elf-finalize.py;
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
    sed
    grep
    diffutils
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
      sed
      grep
      diffutils
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
    "-DLLVM_INCLUDE_TESTS=OFF"
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
  upstreamCmakeFlags = builtins.filter (f: f != "-DLLVM_INCLUDE_TESTS=OFF") final.cmakeFlags ++ [
    "-DLLVM_INCLUDE_TESTS=ON"
  ];
  # The validator owns its own source/build workspace. Test tools, execution and
  # raw failures never participate in either installed-output producer.
  upstreamPlan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = gnutar;
      inherit xz findutils;
    })
    (command "configure" ''
      ${cmake}/bin/cmake -S source/llvm -B build -G Ninja \
        -DCMAKE_MAKE_PROGRAM=${ninja}/bin/ninja -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$out" -DCMAKE_INSTALL_LIBDIR=lib \
        -DCMAKE_INSTALL_RPATH="$out/lib" \
        -DCMAKE_C_COMPILER="$CC" -DCMAKE_CXX_COMPILER="$CXX" \
        -DCMAKE_FIND_USE_PACKAGE_REGISTRY=OFF -DCMAKE_FIND_USE_SYSTEM_PACKAGE_REGISTRY=OFF \
        -DCMAKE_PREFIX_PATH=${
          lib.escapeShellArg (
            lib.concatStringsSep ";" (map (p: "${lib.getDev p}") final.environment.libraries)
          )
        } \
        ${lib.escapeShellArgs final.upstreamCmakeFlags}
    '')
    (command "build" ''${ninja}/bin/ninja -C build -j"$NIX_BUILD_CORES"'')
    (command "check" (
      final.upstreamCheck
      + ''
        mkdir -p "$out"
      ''
    ))
  ];
  upstreamCheck = ''
    ${ninja}/bin/ninja -C build -j"$NIX_BUILD_CORES" FileCheck not
    ${python}/bin/python3 build/bin/llvm-lit -sv -j"$NIX_BUILD_CORES" source/llvm/test/Assembler source/llvm/test/Bitcode
  '';
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
        -DCMAKE_INSTALL_RPATH="$out/lib" \
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
    (command "install" ''
      ${ninja}/bin/ninja -C build -j"$NIX_BUILD_CORES" install
      mkdir -p "$out/nix-support"
      cp build/CMakeCache.txt "$out/nix-support/CMakeCache.txt"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (steps.split "llvm.finalize")
    (outputs.copyArtifacts { inherit coreutils; })
    {
      name = "llvm.relocate-installed";
      tools = [
        coreutils
        helperPython
        binutils
        patchelf
      ];
      run = ''
        # Preserve the immutable original in the artifact. The final tree
        # contains operational metadata only, never a rewritten raw cache.
        rm -- "$out/nix-support/CMakeCache.txt"
        ${helperPython}/bin/python3 -B ${final.finalizer} ${
          lib.escapeShellArg (
            builtins.toJSON {
              rubyFinalizer = final.rubyFinalizer;
              archiveFinalizer = final.archiveFinalizer;
              archiveElfFinalizer = final.archiveElfFinalizer;
              readelf = "${binutils}/bin/readelf";
              patchelf = "${patchelf}/bin/patchelf";
              ar = "${binutils}/bin/ar";
            }
          )
        } "$out" "$TVP_ARTIFACT_ROOT" ${final.elfFinalizer}
      '';
    }
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

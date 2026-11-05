# Compiler only. Build generators and host archives are separate ABI roles.
{
  scope,
  source,
  buildCC,
  hostCC,
  hostTuple,
  targetTuple,
  sysroot,
  hostGmp,
  hostMpfr,
  hostMpc,
  hostBacktrace,
  hostLibiberty,
  buildLibiberty,
  targetBinutils,
  name,
  runtime ? null,
  cxxRuntime ? null,
}:
let
  inherit (scope) bash lib;
  buildTuple = "x86_64-unknown-linux-musl";
  shell = "${bash}/bin/bash";
in
bash.runCommand name
  {
    inherit (source) version meta;
    outputs = [
      "out"
      "evidence"
    ];
    nativeBuildInputs = with scope; [
      buildCC
      binutils
      gnumake-musl
      gnused
      build-grep
      gawk
      diffutils
      findutils
      gnutar-latest
      gzip
      bzip2
      xz
    ];
  }
  ''
      cp -pr ${source.monorepoSrc} source
      chmod -R u+w source
      taskSrc="$PWD/source"
      mkdir build
      cd build
      mkdir -p libbacktrace/.libs libiberty/pic build-${buildTuple}/libiberty
      cp ${hostBacktrace}/lib/libbacktrace.a libbacktrace/.libs/
      cp ${hostBacktrace}/lib/*.la libbacktrace/
      cp ${hostBacktrace}/include/*.h libbacktrace/
      cp ${hostLibiberty}/lib/libiberty.a libiberty/
      cp ${hostLibiberty}/lib/libiberty_pic.a libiberty/pic/
      touch libiberty/stamp-noasandir libiberty/stamp-h libiberty/stamp-picdir
      cp ${buildLibiberty}/lib/libiberty.a build-${buildTuple}/libiberty/
      export CC=${hostCC}/bin/gcc CXX=${hostCC}/bin/g++
      export CC_FOR_BUILD=${buildCC}/bin/gcc CXX_FOR_BUILD=${buildCC}/bin/g++
      export CC_FOR_TARGET=${hostCC}/bin/gcc CXX_FOR_TARGET=${hostCC}/bin/g++
    export GCC_FOR_TARGET=${hostCC}/bin/gcc
    export CFLAGS_FOR_BUILD=-O1 CXXFLAGS_FOR_BUILD=-O1 LDFLAGS_FOR_BUILD=
    export AR=${scope.binutils}/bin/ar NM=${scope.binutils}/bin/nm RANLIB=${scope.binutils}/bin/ranlib
    export OBJDUMP=${scope.binutils}/bin/objdump READELF=${scope.binutils}/bin/readelf
    export STRIP=${scope.binutils}/bin/strip AS=${scope.binutils}/bin/as LD=${scope.binutils}/bin/ld
    export AR_FOR_BUILD=${scope.binutils}/bin/ar NM_FOR_BUILD=${scope.binutils}/bin/nm RANLIB_FOR_BUILD=${scope.binutils}/bin/ranlib
    export OBJDUMP_FOR_BUILD=${scope.binutils}/bin/objdump
    export AS_FOR_BUILD=${scope.binutils}/bin/as LD_FOR_BUILD=${scope.binutils}/bin/ld
      export AS_FOR_TARGET=${targetBinutils}/bin/as LD_FOR_TARGET=${targetBinutils}/bin/ld
      export OBJDUMP_FOR_TARGET=${targetBinutils}/bin/objdump
      export AR_FOR_TARGET=${targetBinutils}/bin/ar NM_FOR_TARGET=${targetBinutils}/bin/nm
      export RANLIB_FOR_TARGET=${targetBinutils}/bin/ranlib READELF_FOR_TARGET=${targetBinutils}/bin/readelf
      export CFLAGS=-O1 CXXFLAGS=-O1
      export LDFLAGS="-Wl,-rpath-link,${sysroot}/lib -Wl,-rpath,${hostMpc}/lib -Wl,-rpath,${hostMpfr}/lib -Wl,-rpath,${hostGmp}/lib"
      export gccng_skip_target_lib_config=y
      ${shell} "$taskSrc/configure" --prefix="$out" \
        --build=${buildTuple} --host=${hostTuple} --target=${targetTuple} \
        --disable-bootstrap --disable-multilib --disable-nls --disable-analyzer \
        --disable-decimal-float --disable-gcov --disable-install-libiberty \
        --disable-libssp --disable-plugin --disable-plugins --disable-lto \
        --enable-languages=c,c++ --enable-threads=posix \
        --without-headers --without-included-gettext --without-isl \
        --with-gnu-as --with-gnu-ld \
        --with-as=${targetBinutils}/bin/as --with-ld=${targetBinutils}/bin/ld \
        --with-sysroot=${sysroot} --with-native-system-header-dir=/include \
        ${
          lib.optionalString (cxxRuntime != null) "--with-gxx-include-dir=${cxxRuntime}/include/c++/16.2.0"
        } \
        --with-gmp=${hostGmp} --with-mpfr=${hostMpfr} --with-mpc=${hostMpc} || { cat config.log; exit 1; }
      sed -i '/TOPLEVEL_CONFIGURE_ARGUMENTS=/d' Makefile
      make -j "$NIX_BUILD_CORES" SHELL=${shell} GCC_FOR_TARGET='./xgcc -B./' all-gcc
      make -j "$NIX_BUILD_CORES" SHELL=${shell} GCC_FOR_TARGET='./xgcc -B./' install-strip-gcc
      rm -rf "$out/libexec/gcc/"*/*/install-tools "$out/lib/gcc/"*/*/install-tools
      rm -rf "$out/share/gcc-"*/python "$out/share/man" "$out/share/info"
      ${
        lib.optionalString (runtime != null && cxxRuntime != null) ''
          rt=${runtime}/lib/gcc/${targetTuple}/16.2.0
          for file in "$rt"/*; do
            test -f "$file" || continue
            ln -sf "$file" "$out/lib/gcc/${targetTuple}/16.2.0/"
          done
          "$out/bin/gcc" -dumpspecs > specs
          # Native raw mode must find the selected target runtime without a wrapper
          # or ambient environment; old dtags also serve libc's unwinder dlopen.
          sed -i '/^\*link:$/ { n; s|^|--disable-new-dtags -rpath-link ${sysroot}/lib -rpath-link ${runtime}/lib/gcc/${targetTuple}/16.2.0 -rpath-link ${cxxRuntime}/lib -rpath ${sysroot}/lib -rpath '"$rt"' -rpath ${cxxRuntime}/lib |; }' specs
          sed -i '/^\*link_libgcc:$/ { n; s|^|-L${cxxRuntime}/lib -L'"$rt"' |; }' specs
          cp specs "$out/lib/gcc/${targetTuple}/16.2.0/specs"
        ''
      }
      mkdir -p "$out/${targetTuple}/bin"
    for tool in as ld ar nm ranlib strip objdump readelf; do
      ln -s ${targetBinutils}/bin/"$tool" "$out/${targetTuple}/bin/$tool"
    done
    mkdir -p "$evidence"
      cp gcc/config.log gcc/auto-host.h "$evidence/"
      mkdir -p "$out/share/licenses/gcc"
      cp "$taskSrc"/COPYING* "$out/share/licenses/gcc/"
  ''

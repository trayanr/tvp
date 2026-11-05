{
  lib,
  buildPlatform,
  hostPlatform,
  fetchurl,
  bash,
  coreutils,
  gcc,
  gcc-buildbuild,
  libgcc,
  binutils,
  gnumake,
  gnupatch,
  gnused,
  gnugrep,
  gawk,
  diffutils,
  findutils,
  gnutar,
  gzip,
  bzip2,
  xz,
  musl,
  libc,
  dynamicLinkerGlob,
  staticLibgcc,
}:
let
  common = import ./gcc-source.nix {
    inherit
      lib
      bash
      fetchurl
      gnupatch
      gnutar
      xz
      gnused
      ;
  };
  pname = "libstdcxx";

  binutilsTargetPrefix = "";

in
bash.runCommand "tvp-bootstrap-gnu-${pname}-${common.version}"
  {
    inherit pname;
    inherit (common) version meta;

    nativeBuildInputs = [
      gcc
      binutils
      gnumake
      gnused
      gnugrep
      gawk
      diffutils
      findutils
      gnutar
      gzip
      bzip2
      xz
    ];
  }
  ''
    # Build from a local copy: diagnostic/configure source paths must not retain
    # the entire patched source tree (and its unused scripts) in runtime closures.
    cp -pr ${common.monorepoSrc} source
    chmod -R u+w source
    taskSrc="$PWD/source"

    # Unpack
    pushd $taskSrc

    mkdir -p "$out/gcc" "$out/libgcc"
    cp gcc/BASE-VER gcc/DATESTAMP "$out/gcc"
    cp libgcc/gthr*.h "$out/libgcc"
    cp libgcc/unwind-pe.h "$out/libgcc"

    cp -r libstdc++-v3 "$out"

    cp -r libiberty "$out"
    cp -r include "$out"
    cp -r contrib "$out"

    cp -r config "$out"
    cp -r multilib.am "$out"

    cp config.guess "$out"
    cp config.rpath "$out"
    cp config.sub "$out"
    cp config-ml.in "$out"
    cp ltmain.sh "$out"
    cp install-sh "$out"
    cp mkinstalldirs "$out"

    [[ -f MD5SUMS ]]; cp MD5SUMS "$out"
    popd

    # Configure
    if [[ -z '${dynamicLinkerGlob}' ]]; then
      echo "Don't know the name of the dynamic linker for platform '${hostPlatform.config}', so guessing instead."
      dynamicLinker="${libc}/lib/ld*.so.?"
    else
      dynamicLinker='${dynamicLinkerGlob}'
    fi
    dynamicLinker=($dynamicLinker)
    case ''${#dynamicLinker[@]} in
      0) echo "No dynamic linker found for platform '${hostPlatform.config}'.";;
      1) echo "Using dynamic linker: '$dynamicLinker'";;
      *) echo "Multiple dynamic linkers found for platform '${hostPlatform.config}'.";;
    esac

    mkdir build; cd build
    export CC=${gcc}/bin/gcc CXX=${gcc}/bin/g++
    export CC_FOR_BUILD=${gcc-buildbuild}/bin/gcc CXX_FOR_BUILD=${gcc-buildbuild}/bin/g++
    export CFLAGS="-O2 -B${binutils}/bin -B${libc}/lib -B${libgcc}/lib/gcc/${hostPlatform.config}/${libgcc.version} -Wl,-dynamic-linker=$dynamicLinker"
    export CXXFLAGS="-O2 -B${binutils}/bin -B${libc}/lib -B${libgcc}/lib/gcc/${hostPlatform.config}/${libgcc.version}${lib.optionalString staticLibgcc " -static-libgcc"} -Wl,-dynamic-linker=$dynamicLinker"
    export LDFLAGS="-B${binutils}/bin -B${libc}/lib -B${libgcc}/lib/gcc/${hostPlatform.config}/${libgcc.version}${lib.optionalString staticLibgcc " -static-libgcc"} -Wl,-dynamic-linker=$dynamicLinker"
    export AR="${binutilsTargetPrefix}ar"
    export LD="${binutilsTargetPrefix}ld"
    export NM="${binutilsTargetPrefix}nm"
    export OBJCOPY="${binutilsTargetPrefix}objcopy"
    $taskSrc/libstdc++-v3/configure \
      --build=${buildPlatform.config} \
      --host=${hostPlatform.config} \
      --prefix="$out" \
      --disable-dependency-tracking \
      gcc_cv_target_thread_file=posix \
      cross_compiling=true \
      --disable-multilib \
      --enable-clocale=gnu \
      --disable-libstdcxx-pch \
      --disable-vtable-verify \
      --enable-libstdcxx-visibility \
      --with-default-libstdcxx-abi=new \
      ${lib.optionalString staticLibgcc "--disable-shared"}

    # Build
    make -j $NIX_BUILD_CORES
    chmod -R +w "$out"

    # Install
    make -j $NIX_BUILD_CORES install-strip

    if [ -d "$out/lib64" ]; then
      shopt -s dotglob
      for lib in $out/lib64/*; do
        mv --no-clobber "$lib" "$out/lib/"
      done
      shopt -u dotglob
      rm -rf "$out/lib64"
      ln -s lib "$out/lib64"
    fi

    # Native musl already uses os/generic. No fake-tuple self-link is needed.
    # Installed headers (including .tcc), static libraries and licenses survive;
    # copied configure/build sources are not runtime inputs.
    rm -rf "$out/gcc" "$out/libgcc" "$out/libstdc++-v3" "$out/libiberty" \
      "$out/contrib" "$out/config"
    rm -f "$out/"{config.guess,config.rpath,config.sub,config-ml.in,ltmain.sh,install-sh,mkinstalldirs,multilib.am,MD5SUMS}
    # configure used taskSrc/include, not this copied GCC support include tree.
    # Installed C++ headers live under include/c++; preserve that entire subtree.
    for entry in "$out/include/"*; do
      case "$entry" in "$out/include/c++") ;; *) rm -rf "$entry";; esac
    done
    mkdir -p "$out/share/licenses/${pname}"
    cp $taskSrc/COPYING* "$out/share/licenses/${pname}/"
  ''

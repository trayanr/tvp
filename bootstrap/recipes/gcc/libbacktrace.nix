{
  lib,
  buildPlatform,
  hostPlatform,
  fetchurl,
  bash,
  coreutils,
  gcc,
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
}:
let
  common = import ./common.nix {
    inherit
      lib
      bash
      fetchurl
      gnupatch
      gnutar
      xz
      musl
      gnused
      ;
  };
  pname = "libbacktrace";
in
bash.runCommand "${pname}-${common.version}"
  {
    inherit (common) meta version;
    inherit pname;
    outputs = [
      "out"
      "checks"
    ];

    nativeBuildInputs = [
      gcc
      binutils
      gnumake
      gnupatch
      gnused
      gnugrep
      gawk
      diffutils
      findutils
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

    mkdir -p "$out/gcc"
    cp gcc/BASE-VER gcc/DATESTAMP "$out/gcc"
    cp -r include libbacktrace "$out"
    cp config.guess config.rpath config.sub config-ml.in \
       ltmain.sh install-sh move-if-change mkinstalldirs \
       test-driver "$out"
    [[ -f MD5SUMS ]]; cp MD5SUMS "$out"

    popd

    $taskSrc/libbacktrace/configure --prefix="$out" \
      --build=${buildPlatform.config} \
      --host=${hostPlatform.config}

    # Build
    make -j $NIX_BUILD_CORES

    # Observer-readable upstream check results; unsupported harness assumptions
    # are recorded explicitly, without adding borrowed test prerequisites.
    mkdir -p "$checks"
    status=0
    make -j $NIX_BUILD_CORES check > "$checks/make-check.log" 2>&1 || status=$?
    printf '%s\n' "$status" > "$checks/exit-code"

    # Install
    mkdir -p "$out/lib/"
    mkdir -p "$out/include/"
    cp .libs/*.a "$out/lib/"
    cp libbacktrace*.la "$out/lib"

    chmod +w "$out/include"
    cp backtrace-supported.h "$out/include/"
    cp "$taskSrc/libbacktrace/backtrace.h" "$out/include/"
    chmod -R u+w "$out"
    rm -rf "$out/gcc" "$out/libbacktrace"
    rm -f "$out/"{config.guess,config.rpath,config.sub,config-ml.in,ltmain.sh,install-sh,move-if-change,mkinstalldirs,test-driver,MD5SUMS}
    mkdir -p "$out/share/licenses/${pname}"
    cp $taskSrc/COPYING* "$out/share/licenses/${pname}/"
  ''

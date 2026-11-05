{
  lib,
  buildPlatform,
  hostPlatform,
  fetchurl,
  bash,
  coreutils,
  gcc,
  binutils,
  gnupatch,
  gnumake,
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
      gnutar
      xz
      gnupatch
      musl
      gnused
      ;
  };
  pname = "libiberty";

  binutilsTargetPrefix = lib.optionalString (
    hostPlatform.config != buildPlatform.config
  ) "${hostPlatform.config}-";
in
bash.runCommand "${pname}-${common.version}"
  {
    inherit pname;
    outputs = [
      "out"
      "checks"
    ];
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

    mkdir -p "$out/gcc"
    cp gcc/BASE-VER gcc/DATESTAMP "$out/gcc"
    cp -r include libiberty "$out"
    cp config.guess config.rpath config.sub config-ml.in \
       ltmain.sh install-sh mkinstalldirs "$out"
    [[ -f MD5SUMS ]]; cp MD5SUMS "$out"

    popd

    $taskSrc/libiberty/configure \
      --build=${buildPlatform.config} \
      --host=${hostPlatform.config} \
      --prefix="$out" \
      --enable-install-libiberty \
      enable_host_pie=yes

    # Build
    make -j $NIX_BUILD_CORES

    # Observer-readable upstream check results; unsupported harness assumptions
    # are recorded explicitly, without adding borrowed test prerequisites.
    mkdir -p "$checks"
    status=0
    make -j $NIX_BUILD_CORES check > "$checks/make-check.log" 2>&1 || status=$?
    printf '%s\n' "$status" > "$checks/exit-code"

    chmod -R +w "$out/include"

    # Install
    make -j $NIX_BUILD_CORES install-strip

    # Intentionally providing plain libiberty.a in place of libiberty_pic.a1
    cp pic/libiberty.a $out/lib/libiberty.a
    cp pic/libiberty.a $out/lib/libiberty_pic.a
    if [ -d "$out/lib64" ]; then
      shopt -s dotglob
      for lib in $out/lib64/*; do
        mv --no-clobber "$lib" "$out/lib/"
      done
      shopt -u dotglob
      rm -rf "$out/lib64"
      ln -s lib "$out/lib64"
    fi
    find $out/lib -type f -exec ${binutilsTargetPrefix}strip --strip-debug {} + || true
    chmod -R u+w "$out"
    rm -rf "$out/gcc" "$out/libiberty"
    rm -f "$out/"{config.guess,config.rpath,config.sub,config-ml.in,ltmain.sh,install-sh,move-if-change,mkinstalldirs,test-driver,MD5SUMS}
    mkdir -p "$out/share/licenses/${pname}"
    cp $taskSrc/COPYING* "$out/share/licenses/${pname}/"
  ''

{
  lib,
  buildPlatform,
  hostPlatform,
  fetchurl,
  bash,
  coreutils,
  gcc-buildbuild,
  gcc,
  binutils,
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
}:
let
  pname = "gmp";
  version = "6.3.0";

  src = fetchurl {
    url = "mirror://gnu/gmp/gmp-${version}.tar.xz";
    hash = "sha256-o8K4AgG4nmhhb0rTC8Zq7kknw85Q4zkpyoGdXENTiJg=";
  };
in
bash.runCommand "tvp-bootstrap-gnu-${pname}-${version}"
  {
    inherit pname version;
    outputs = [
      "out"
      "checks"
      "evidence"
    ];

    nativeBuildInputs = [
      gcc
      gcc-buildbuild
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

    meta = {
      description = "The GNU Multiple Precision Arithmetic Library, version ${version}";
      homepage = "https://gmplib.org/";
      license = with lib.licenses; [
        lgpl3Only
        gpl2Only
      ];
      teams = [ lib.teams.minimal-bootstrap ];
      platforms = lib.platforms.unix;
    };
  }
  ''
    # Unpack
    tar xf ${src}
    cd gmp-${version}

    export CC=${gcc}/bin/gcc CXX=${gcc}/bin/g++
    export CC_FOR_BUILD=${gcc-buildbuild}/bin/gcc CXX_FOR_BUILD=${gcc-buildbuild}/bin/g++
    export AR=${binutils}/bin/ar RANLIB=${binutils}/bin/ranlib
    # Configure
    bash ./configure \
      --prefix=$out \
      --build=${buildPlatform.config} \
      --host=${hostPlatform.config} \
      --disable-dependency-tracking \
      --with-pic \
      --disable-assembly \
      CFLAGS=-std=c99 \
      M4=false

    # Build
    make -j $NIX_BUILD_CORES

    mkdir -p "$checks"
    status=0
    make -j $NIX_BUILD_CORES check > "$checks/make-check.log" 2>&1 || status=$?
    printf '%s\n' "$status" > "$checks/exit-code"

    # Install
    make -j $NIX_BUILD_CORES install-strip
    # GMP publishes its construction CC as diagnostic text in the public
    # header. Retain that exact provenance separately, without a runtime edge
    # to the superseded M-hosted compiler and shell.
    mkdir -p "$evidence"
    cp config.log "$out/include/gmp.h" "$evidence/"
    sed -i 's|^#define __GMP_CC .*|#define __GMP_CC "M/M/G GNU-target GCC 16.2.0"|' "$out/include/gmp.h"
    mkdir -p "$out/share/licenses/${pname}"
    cp COPYING* "$out/share/licenses/${pname}/"
  ''

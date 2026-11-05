{
  lib,
  buildPlatform,
  hostPlatform,
  fetchurl,
  bash,
  coreutils,
  gcc,
  gcc-buildbuild,
  binutils,
  gnumake,
  gnused,
  gnugrep,
  gawk,
  diffutils,
  findutils,
  gnutar,
  xz,
  libgmp,
}:
let
  pname = "mpfr";
  version = "4.2.2";

  src = fetchurl {
    url = "mirror://gnu/mpfr/mpfr-${version}.tar.xz";
    hash = "sha256-tnugOD736KhWNzTi6InvXsPDuJigHQD6CmhprYHGzgE=";
  };
in
bash.runCommand "tvp-bootstrap-gnu-${pname}-${version}"
  {
    inherit pname version;
    outputs = [
      "out"
      "checks"
    ];

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
      xz
    ];

    meta = {
      description = "The GNU Multiple Precision Floating-Point Reliable Library, version ${version}";
      homepage = "https://www.mpfr.org/";
      license = lib.licenses.lgpl3Plus;
      teams = [ lib.teams.minimal-bootstrap ];
      platforms = lib.platforms.unix;
    };
  }
  ''
    # Unpack
    tar xf ${src}
    cd mpfr-${version}

    export CC=${gcc}/bin/gcc CXX=${gcc}/bin/g++
    export CC_FOR_BUILD=${gcc-buildbuild}/bin/gcc CXX_FOR_BUILD=${gcc-buildbuild}/bin/g++
    export AR=${binutils}/bin/ar RANLIB=${binutils}/bin/ranlib
    # Configure
    bash ./configure \
      --prefix=$out \
      --build=${buildPlatform.config} \
      --host=${hostPlatform.config} \
      --disable-dependency-tracking \
      --with-gmp=${libgmp}

    # Build
    make -j $NIX_BUILD_CORES

    mkdir -p "$checks"
    status=0
    make -j $NIX_BUILD_CORES check > "$checks/make-check.log" 2>&1 || status=$?
    printf '%s\n' "$status" > "$checks/exit-code"

    # Install
    make -j $NIX_BUILD_CORES install-strip
    mkdir -p "$out/share/licenses/${pname}"
    cp COPYING* "$out/share/licenses/${pname}/"
  ''

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
  gzip,
  bzip2,
  xz,
  libgmp,
  libmpfr,
}:
let
  pname = "mpc";
  version = "1.3.1";
  src = fetchurl {
    url = "mirror://gnu/mpc/mpc-${version}.tar.gz";
    hash = "sha256-q2QkkvXPiCt0qgy3MM1BCoHtzb7IlRg86TDnBsHHWbg=";
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
      gzip
      bzip2
      xz
    ];

    meta = {
      description = "GNU Multiple Precision Complex Library, version ${version}";
      homepage = "https://www.multiprecision.org/";
      license = lib.licenses.lgpl3Plus;
      teams = [ lib.teams.minimal-bootstrap ];
      platforms = lib.platforms.unix;
    };
  }
  ''
    # Unpack
    tar xf ${src}
    cd mpc-${version}

    export CC=${gcc}/bin/gcc CXX=${gcc}/bin/g++
    export CC_FOR_BUILD=${gcc-buildbuild}/bin/gcc CXX_FOR_BUILD=${gcc-buildbuild}/bin/g++
    export AR=${binutils}/bin/ar RANLIB=${binutils}/bin/ranlib
    # Configure
    bash ./configure \
      --prefix=$out \
      --build=${buildPlatform.config} \
      --host=${hostPlatform.config} \
      --disable-dependency-tracking \
      --with-gmp=${libgmp} \
      --with-mpfr=${libmpfr}

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

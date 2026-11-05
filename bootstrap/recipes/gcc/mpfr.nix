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
bash.runCommand "${pname}-${version}"
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
    make -j $NIX_BUILD_CORES check > "$checks/make-check.log" 2>&1

    # Install
    make -j $NIX_BUILD_CORES install-strip
    mkdir -p "$out/share/licenses/${pname}"
    cp COPYING* "$out/share/licenses/${pname}/"
  ''

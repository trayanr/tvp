# Python 3.5/3.6 predate Setup.local disabled-module declarations. Configure
# its upstream setup.py exclusion list instead of changing feature detection.
{
  lib,
  stdenv,
  fetchurl,
  bash,
  openssl,
  zlib,
  bzip2,
  xz,
  pkg-config,
  libffi,
  sqlite,
  gdbm,
  readline,
  ncurses,
  libxcrypt,
  pkgConfigRequired ? false,
  opensslRpath ? true,
  systemFfi ? false,
  opensslPrefix ? true,
  platlibdir ? true,
  finalizeEx ? true,
  embedFlag ? true,
  textSubprocess ? true,
  disabledModules,
  upstreamModules ? [
    "test_ssl"
    "test_hashlib"
    "test_ctypes"
    "test_sqlite3"
    "test_dbm_gnu"
    "test_dbm_ndbm"
    "test_bz2"
    "test_lzma"
    "test_zlib"
    "test_readline"
  ],
  version,
  sha256,
  patches ? [ ],
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "python";
  inherit version patches;
  src = fetchurl {
    url = "https://www.python.org/ftp/python/${version}/Python-${version}.tar.xz";
    inherit sha256;
  };
  nativeBuildInputs = [ pkg-config ];
  # Curses headers live in the wide-character include directory.
  NIX_CFLAGS_COMPILE = "-I${lib.getDev ncurses}/include/ncursesw";
  buildInputs = [
    openssl
    zlib
    bzip2
    xz
    libffi
    sqlite
    gdbm
    readline
    ncurses
    libxcrypt
  ];
  # Older Python.h exposes crypt.h as part of its public C API.
  propagatedBuildInputs = [ libxcrypt ];
  # Setup.local is upstream's supported module-selection interface. Explicit
  # disabling prevents host probes from changing this build interpreter's API.
  preConfigure = ''
    # Set these after stdenv setup: distutils inspects the configured name
    # to choose GNU linker syntax.
    export CC="${stdenv.cc}/bin/gcc" CXX="${stdenv.cc}/bin/g++"
    # python-config exposes LIBS, but omits LDFLAGS from embedding flags.
    export LIBS="-L${lib.getLib libxcrypt}/lib -Wl,-rpath,${lib.getLib libxcrypt}/lib"
    export PKG_CONFIG_PATH="${
      lib.makeSearchPath "lib/pkgconfig" [
        openssl
        zlib
        bzip2
        xz
        libffi
        sqlite
        gdbm
        readline
        ncurses
        libxcrypt
      ]
    }"
    export CPPFLAGS="${
      lib.concatMapStringsSep " " (dep: "-I${lib.getDev dep}/include") [
        openssl
        zlib
        bzip2
        xz
        libffi
        sqlite
        gdbm
        readline
        ncurses
        libxcrypt
      ]
    } -I${lib.getDev ncurses}/include/ncursesw"
    export LDFLAGS="${
      lib.concatMapStringsSep " " (dep: "-L${lib.getLib dep}/lib") [
        openssl
        zlib
        bzip2
        xz
        libffi
        sqlite
        gdbm
        readline
        ncurses
        libxcrypt
      ]
    }"
    : > Modules/Setup.local
    substituteInPlace setup.py --replace-fail '@TVP_DISABLED_MODULES@' ${lib.escapeShellArg (builtins.toJSON disabledModules)}
    substituteInPlace Lib/subprocess.py \
      --replace-fail '@TVP_SHELL@' '${bash}/bin/bash'
  '';
  configureFlags =
    [
      "--with-ensurepip=install"
      "--with-dbmliborder=gdbm"
    ]
    ++ lib.optional pkgConfigRequired "--with-pkg-config=yes"
    ++ lib.optional opensslRpath "--with-openssl-rpath=auto"
    ++ lib.optional platlibdir "--with-platlibdir=lib"
    ++ lib.optional systemFfi "--with-system-ffi"
    ++ lib.optional opensslPrefix "--with-openssl=${openssl}";
  enableParallelBuilding = true;
  # compileall's default process count ignores Nix's per-build CPU allocation.
  preInstall = ''
    installFlagsArray+=("COMPILEALL_OPTS=-j$NIX_BUILD_CORES")
  '';
  meta = {
    description = "General-purpose CPython interpreter with native extension and virtual environment support";
    homepage = "https://www.python.org/";
    license = lib.licenses.psfl;
    platforms = [ "x86_64-linux" ];
    mainProgram = "python3";
  };
  passthru = {
    tvp.deps = {
      inherit
        bash
        openssl
        zlib
        bzip2
        xz
        pkg-config
        libffi
        sqlite
        gdbm
        readline
        ncurses
        libxcrypt
        ;
    };
    tvp.cc = stdenv.cc;
    tvp.profile = "general-purpose";
    tvp.features = {
      externalModules = true;
      tls = true;
      archiveCompression = true;
      pipInstalled = true;
    };
    tvp.features.finalizeEx = finalizeEx;
    tvp.features.embedFlag = embedFlag;
    tvp.features.textSubprocess = textSubprocess;
    tvp.disabledModules = disabledModules;
    tvp.upstreamModules = upstreamModules;
    tests = mkTests finalAttrs.finalPackage;
  };
})

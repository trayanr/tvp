# Python 3.12 builds standard-library extensions directly from configure
# results rather than setup.py. Explicit inputs select the CLI profile.
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
  finalizeEx ? true,
  embedFlag ? true,
  textSubprocess ? true,
  linkUnwinder ? false,
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
  env = lib.optionalAttrs linkUnwinder {
    # Native thread exit needs glibc's lazily loaded compiler unwinder even
    # when the interpreter has no direct reference to its symbols.
    NIX_LDFLAGS = "--no-as-needed -lgcc_s --as-needed";
  };
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
  # Setup.local is upstream's supported module-selection interface. Explicit
  # disabling prevents host probes from changing this build interpreter's API.
  preConfigure = ''
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
    printf '%s\n' '*disabled*' ${lib.escapeShellArgs disabledModules} > Modules/Setup.local
    substituteInPlace Lib/subprocess.py \
      --replace-fail '@TVP_SHELL@' '${bash}/bin/bash'
  '';
  configureFlags = [
    "--with-ensurepip=install"
    "--with-pkg-config=yes"
    "--with-dbmliborder=gdbm"
    "--with-platlibdir=lib"
    "--with-openssl=${openssl}"
    "--with-openssl-rpath=auto"
  ];
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
    tvp.features.linkUnwinder = linkUnwinder;
    tvp.disabledModules = disabledModules;
    tvp.upstreamModules = upstreamModules;
    tests = mkTests finalAttrs.finalPackage;
  };
})

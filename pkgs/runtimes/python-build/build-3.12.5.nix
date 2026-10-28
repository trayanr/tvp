# CPython build-tools profile with TLS and archive modules, without GUI dependencies.
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
  disabledModules,
  version,
  sha256,
  patches ? [ ],
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "python-build";
  inherit version patches;
  src = fetchurl {
    url = "https://www.python.org/ftp/python/${version}/Python-${version}.tar.xz";
    inherit sha256;
  };
  nativeBuildInputs = [ pkg-config ];
  buildInputs = [
    openssl
    zlib
    bzip2
    xz
  ];
  # Setup.local is upstream's supported module-selection interface. Explicit
  # disabling prevents host probes from changing this build interpreter's API.
  preConfigure = ''
    printf '%s\n' '*disabled*' ${lib.escapeShellArgs disabledModules} > Modules/Setup.local
    substituteInPlace Lib/subprocess.py \
      --replace-fail '@TVP_SHELL@' '${bash}/bin/bash'
  '';
  configureFlags = [
    "--without-ensurepip"
    "--without-readline"
    "--disable-test-modules"
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
    description = "CPython build-tools profile with TLS and archive support";
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
        ;
    };
    tvp.cc = stdenv.cc;
    tvp.profile = "build-tools";
    tvp.features = {
      externalModules = true;
      tls = true;
      archiveCompression = true;
      pipInstalled = false;
    };
    tvp.disabledModules = disabledModules;
    tests = mkTests finalAttrs.finalPackage;
  };
})

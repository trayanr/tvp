# A source-built interpreter for build scripts, with an explicit minimal profile.
{
  lib,
  stdenv,
  fetchurl,
  bash,
  disabledModules,
  version,
  sha256,
  patches ? [ ],
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "python-minimal";
  inherit version patches;
  src = fetchurl {
    url = "https://www.python.org/ftp/python/${version}/Python-${version}.tar.xz";
    inherit sha256;
  };
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
  ];
  enableParallelBuilding = true;
  # compileall's default process count ignores Nix's per-build CPU allocation.
  preInstall = ''
    installFlagsArray+=("COMPILEALL_OPTS=-j$NIX_BUILD_CORES")
  '';
  meta = {
    description = "Minimal CPython interpreter for build scripts, without third-party extension libraries";
    homepage = "https://www.python.org/";
    license = lib.licenses.psfl;
    platforms = [ "x86_64-linux" ];
    mainProgram = "python3";
  };
  passthru = {
    tvp.deps = {
      inherit bash;
    };
    tvp.cc = stdenv.cc;
    tvp.profile = "build";
    tvp.features = {
      externalModules = false;
      pipInstalled = false;
    };
    tvp.disabledModules = disabledModules;
    tests = mkTests finalAttrs.finalPackage;
  };
})

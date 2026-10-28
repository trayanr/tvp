{
  lib,
  stdenv,
  fetchurl,
  autoconf,
  perl,
  version,
  sha256,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "automake";
  inherit version;
  src = fetchurl {
    url = "https://mirrors.kernel.org/gnu/automake/automake-${version}.tar.xz";
    inherit sha256;
  };
  nativeBuildInputs = [
    autoconf
    perl
  ];
  propagatedBuildInputs = [ autoconf ];
  configureFlags = [
    "PERL=${perl}/bin/perl"
    "AUTOCONF=${autoconf}/bin/autoconf"
    "AUTOM4TE=${autoconf}/bin/autom4te"
    "AUTORECONF=${autoconf}/bin/autoreconf"
    "AUTOHEADER=${autoconf}/bin/autoheader"
    "AUTOUPDATE=${autoconf}/bin/autoupdate"
  ];
  enableParallelBuilding = true;
  postInstall = ''
    mkdir -p "$out/nix-support"
    cp ${./setup-hook.sh} "$out/nix-support/setup-hook"
  '';
  meta = {
    description = "GNU Makefile generator and aclocal macro collector";
    homepage = "https://www.gnu.org/software/automake/";
    license = lib.licenses.gpl2Plus;
    platforms = [ "x86_64-linux" ];
    mainProgram = "automake";
  };
  passthru = {
    tvp.deps = {
      inherit autoconf perl;
    };
    tvp.cc = stdenv.cc;
    tests = mkTests finalAttrs.finalPackage;
  };
})

# Before 1.6, configure treats VAR=value arguments as host names; tool paths
# must be supplied through the environment.
{
  lib,
  stdenv,
  fetchurl,
  autoconf,
  perl,
  version,
  sha256,
  patches ? [ ],
  archiveExt ? "tar.xz",
  installAclocalDir ? false,
  headerMacro ? "AC_CONFIG_HEADERS",
  automaticCcCo ? true,
  hasAclocal ? true,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "automake";
  inherit version patches;
  src = fetchurl {
    url = "https://mirrors.kernel.org/gnu/automake/automake-${version}.${archiveExt}";
    inherit sha256;
  };
  nativeBuildInputs = [
    autoconf
    perl
  ];
  propagatedBuildInputs = [ autoconf ];
  env = {
    PERL = "${perl}/bin/perl";
    AUTOCONF = "${autoconf}/bin/autoconf";
    AUTOM4TE = "${autoconf}/bin/autom4te";
    AUTORECONF = "${autoconf}/bin/autoreconf";
    AUTOHEADER = "${autoconf}/bin/autoheader";
    AUTOUPDATE = "${autoconf}/bin/autoupdate";
  };
  enableParallelBuilding = true;
  postInstall =
    ''
      mkdir -p "$out/nix-support"
      cp ${./setup-hook.sh} "$out/nix-support/setup-hook"
    ''
    + lib.optionalString installAclocalDir ''
      mkdir -p "$out/share/aclocal"
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
    tvp.headerMacro = headerMacro;
    tvp.features.automaticCcCo = automaticCcCo;
    tvp.features.aclocal = hasAclocal;
    tests = mkTests finalAttrs.finalPackage;
  };
})

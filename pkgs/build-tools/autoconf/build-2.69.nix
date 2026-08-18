# Serves 2.69 onwards.
{
  lib,
  stdenv,
  fetchurl,

  m4,
  perl,

  version,
  sha256,

  # Supplied by default.nix. A fork that drops this argument fails to evaluate.
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "autoconf";
  inherit version;

  # .tar.gz is the only format present across the whole line: .tar.bz2 covers
  # only 2.52-2.68 and .tar.xz starts at 2.64.
  src = fetchurl {
    url = "https://ftp.gnu.org/gnu/autoconf/autoconf-${version}.tar.gz";
    inherit sha256;
  };

  # m4 and perl are what autoconf *runs*, not what it links, so they are
  # nativeBuildInputs here and propagated references in the installed scripts.
  nativeBuildInputs = [
    m4
    perl
  ];

  meta = {
    description = "Tool for producing configure scripts for building software";
    homepage = "https://www.gnu.org/software/autoconf/";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.unix;
    mainProgram = "autoconf";
  };

  passthru = {
    inherit version;
    tvp.deps = {
      inherit m4 perl;
    };

    tests = mkTests finalAttrs.finalPackage;
  };
})

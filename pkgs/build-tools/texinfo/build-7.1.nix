{
  lib,
  stdenv,
  fetchurl,
  perl,
  ncurses,
  localeTools,
  version,
  sha256,
  patches ? [ ],
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "texinfo";
  inherit version patches;
  src = fetchurl {
    url = "https://mirrors.kernel.org/gnu/texinfo/texinfo-${version}.tar.xz";
    inherit sha256;
  };
  nativeBuildInputs = [ perl ];
  buildInputs = [ ncurses ];
  postPatch = ''
    patchShebangs tp/maintain
    substituteInPlace tp/Texinfo/Translations.pm \
      --replace-fail '@TVP_LOCALE@' '${localeTools}/bin/locale'
  '';
  env.NIX_CFLAGS_COMPILE = "-I${lib.getDev ncurses}/include/ncursesw";
  configureFlags = [
    "PERL=${perl}/bin/perl"
    "--enable-perl-xs=yes"
  ];
  enableParallelBuilding = true;
  installFlags = [ "TEXMF=$(out)/texmf-dist" ];
  installTargets = [
    "install"
    "install-tex"
  ];
  meta = {
    description = "GNU Texinfo documentation tools and Info reader";
    homepage = "https://www.gnu.org/software/texinfo/";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
    mainProgram = "makeinfo";
  };
  passthru = {
    tvp.deps = {
      inherit perl ncurses localeTools;
    };
    tests = mkTests finalAttrs.finalPackage;
  };
})

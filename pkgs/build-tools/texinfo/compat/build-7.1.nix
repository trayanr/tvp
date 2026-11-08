# Measured ordinary reverse-consumer compatibility for the owned Perl Config compiler.
# Keep build-7.1.nix and source-owned generations exact for captured callers.
{
  lib,
  stdenv,
  fetchurl,
  perl,
  ncurses,
  localeTools,
  version,
  sha256,
  cStandard ? null,
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
  env.NIX_CFLAGS_COMPILE =
    "-I${lib.getDev ncurses}/include/ncursesw"
    + lib.optionalString (
      cStandard != null && lib.versionAtLeast stdenv.cc.version "15"
    ) " -std=${cStandard}";
  # Texinfo selects Config's compiler for XS. Its parent still uses the legacy
  # compiler environment; clear that parent's unsupported hardening request only
  # inside the owned compiler invocation. Explicit C/CPP/link flags are retained.
  preConfigure = ''
    cat > .tvp-perl-xs-cc <<'SH'
    #!${stdenv.shell}
    unset NIX_HARDENING_ENABLE
    exec ${perl}/bin/perl -MConfig -MText::ParseWords -e 'my @cc = Text::ParseWords::shellwords($Config{cc}); exec { $cc[0] } @cc, @ARGV; die "Config compiler exec failed: $!";' -- "$@"
    SH
    chmod +x .tvp-perl-xs-cc
    export PERL_EXT_CC="$PWD/.tvp-perl-xs-cc"
  '';
  # Upstream otherwise silently falls back to pure Perl after an XS configure
  # failure. The ordinary profile requires this interface.
  postConfigure = ''test -f tp/Texinfo/XS/Makefile'';
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

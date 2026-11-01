# Serves 5.2.37 onwards.
{
  lib,
  stdenv,
  fetchurl,
  ncurses,
  version,
  sha256,
  cStandard ? null,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "bash";
  inherit version;
  src = fetchurl {
    url = "https://mirrors.kernel.org/gnu/bash/bash-${version}.tar.gz";
    inherit sha256;
  };
  buildInputs = [ ncurses ];
  enableParallelBuilding = true;
  configureFlags = [ "--with-curses" ];
  env =
    {
      LIBS = "-lncursesw";
    }
    // lib.optionalAttrs (cStandard != null && lib.versionAtLeast stdenv.cc.version "15") {
      NIX_CFLAGS_COMPILE = "-std=${cStandard}";
    };
  postInstall = ''
    ln -s bash "$out/bin/sh"
    # Installed helpers belong to this shell, not the shell which built it.
    sed -i "1c#!$out/bin/bash" "$out/bin/bashbug"
    substituteInPlace "$out/lib/bash/Makefile.inc" \
      --replace-fail "$(command -v install)" install
    printf '\nSHELL = %s/bin/bash\n' "$out" >> "$out/lib/bash/Makefile.inc"
  '';

  meta = {
    description = "GNU Bourne Again Shell";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.unix;
  };
  passthru = {
    tvp.deps = {
      inherit ncurses;
    };
    tvp.cc = stdenv.cc;
    tests = mkTests finalAttrs.finalPackage;
  };
})

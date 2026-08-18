# Serves 1.23 onwards.
{
  lib,
  stdenv,
  fetchurl,

  version,
  sha256,

  # Supplied by default.nix. A fork that drops this argument fails to evaluate.
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "gdbm";
  inherit version;

  src = fetchurl {
    url = "https://ftp.gnu.org/gnu/gdbm/gdbm-${version}.tar.gz";
    inherit sha256;
  };

  # ndbm.h and the dbm/ndbm entry points live in libgdbm_compat, which is off by
  # default. Ruby's ext/dbm needs them.
  configureFlags = [ "--enable-libgdbm-compat" ];

  enableParallelBuilding = true;
  doCheck = true;

  # Consumers written against the traditional layout include <gdbm/ndbm.h>.
  postInstall = ''
    install -dm755 "$out/include/gdbm"
    ln -s ../dbm.h ../gdbm.h ../ndbm.h "$out/include/gdbm/"
  '';

  meta = {
    description = "GNU dbm key/value database library";
    homepage = "https://www.gnu.org/software/gdbm/";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.unix;
    mainProgram = "gdbmtool";
  };

  passthru = {
    inherit version;
    tvp.deps = { };

    tests = mkTests finalAttrs.finalPackage;
  };
})

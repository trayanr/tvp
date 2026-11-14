{
  lib,
  stdenv,
  fetchurl,
  version,
  sha256,
  linkWithCC ? false,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "mpdecimal";
  inherit version;
  src = fetchurl {
    url = "https://www.bytereef.org/software/mpdecimal/releases/mpdecimal-${version}.tar.gz";
    inherit sha256;
  };
  configureFlags = [
    "--enable-shared"
    "--enable-cxx"
  ] ++ lib.optional linkWithCC "LD=cc";
  enableParallelBuilding = true;
  doCheck = true;
  # Upstream's offline target exercises the release's shipped test corpus.
  checkTarget = "check_local";
  meta = {
    description = "Correctly rounded arbitrary-precision decimal arithmetic libraries";
    homepage = "https://www.bytereef.org/mpdecimal/";
    license = lib.licenses.bsd2;
    platforms = [ "x86_64-linux" ];
  };
  passthru = {
    tvp.deps = { };
    tvp.cc = stdenv.cc;
    tests = mkTests finalAttrs.finalPackage;
  };
})

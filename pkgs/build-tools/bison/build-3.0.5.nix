# GNU release tarballs include generated parsers and manuals: no Bison bootstrap.
{
  lib,
  stdenv,
  fetchurl,
  m4,
  perl,
  version,
  sha256,
  mkTests,
  patches ? [ ],
  postPatch ? null,
}:
stdenv.mkDerivation (
  finalAttrs:
  {
    pname = "bison";
    inherit version;
    src = fetchurl {
      url = "https://mirrors.kernel.org/gnu/bison/bison-${version}.tar.gz";
      inherit sha256;
    };
    nativeBuildInputs = [
      m4
      perl
    ];
    # The configured M4 path is used when Bison generates a parser at runtime.
    configureFlags = [ "M4=${m4}/bin/m4" ];
    enableParallelBuilding = true;
    meta = {
      description = "GNU parser generator";
      homepage = "https://www.gnu.org/software/bison/";
      license = lib.licenses.gpl3Plus;
      platforms = lib.platforms.unix;
      mainProgram = "bison";
    };
    passthru = {
      tvp.deps = {
        inherit m4 perl;
      };
      tvp.cc = stdenv.cc;
      tests = mkTests finalAttrs.finalPackage;
    };
  }
  // lib.optionalAttrs (patches != [ ]) {
    inherit patches;
  }
  // lib.optionalAttrs (postPatch != null) {
    inherit postPatch;
  }
)

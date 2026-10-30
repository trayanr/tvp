{
  lib,
  stdenv,
  fetchurl,
  bison,
  m4,
  version,
  sha256,
  patches ? [ ],
  mkTests,
}:
stdenv.mkDerivation (
  finalAttrs:
  {
    pname = "flex";
    inherit version;
    src = fetchurl {
      url = "https://github.com/westes/flex/releases/download/v${version}/flex-${version}.tar.gz";
      inherit sha256;
    };
    nativeBuildInputs = [
      bison
      m4
    ];
    propagatedBuildInputs = [ m4 ];
    configureFlags = [ "M4=${m4}/bin/m4" ];
    enableParallelBuilding = true;
    postInstall = ''
      ln -s flex "$out/bin/lex"
    '';
    meta = {
      description = "Lexical analyser generator for C and C++";
      homepage = "https://github.com/westes/flex";
      license = lib.licenses.bsd2;
      platforms = [ "x86_64-linux" ];
      mainProgram = "flex";
    };
    passthru = {
      tvp.deps = {
        inherit bison m4;
      };
      tvp.cc = stdenv.cc;
      tests = mkTests finalAttrs.finalPackage;
    };
  }
  // lib.optionalAttrs (patches != [ ]) { inherit patches; }
)

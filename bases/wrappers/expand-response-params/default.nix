# Build with the frozen owned parent, never the default being constructed.
{ stdenv }:
stdenv.mkDerivation {
  name = "tvp-expand-response-params-v3";
  dontUnpack = true;
  dontConfigure = true;
  buildPhase = ''
    cc -std=c99 -O2 -Wall -Wextra -Werror ${./expand-response-params.c} -o expand-response-params
  '';
  installPhase = ''
    mkdir -p "$out/bin"
    cp expand-response-params "$out/bin/"
  '';
}

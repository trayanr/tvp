{
  lib,
  stdenv,
  fetchurl,
  patchelf,
  dynamicLinker,
  triple,
  version,
  sha256,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "cargo-bootstrap";
  inherit version;
  src = fetchurl {
    url = "https://static.rust-lang.org/dist/rust-${version}-${triple}.tar.gz";
    inherit sha256;
  };
  nativeBuildInputs = [ patchelf ];
  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;
  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -a cargo/bin cargo/etc cargo/share "$out/"
    chmod u+w "$out/bin/cargo"
    patchelf --set-interpreter '${stdenv.cc.libc}/${dynamicLinker}' \
      --set-rpath '${stdenv.cc.libc}/lib:${lib.getLib stdenv.cc.cc}/lib' "$out/bin/cargo"
    runHook postInstall
  '';
  meta = {
    description = "Explicit binary Cargo bootstrap from the upstream Rust distribution";
    homepage = "https://doc.rust-lang.org/cargo/";
    license = [
      lib.licenses.mit
      lib.licenses.asl20
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "cargo";
  };
  passthru = {
    tvp.deps = {
      inherit patchelf;
    };
    tests = mkTests finalAttrs.finalPackage;
  };
})

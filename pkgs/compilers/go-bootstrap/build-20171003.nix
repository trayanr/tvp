# Upstream's dated C-based bootstrap distribution, not a patched TVP Go release.
{
  lib,
  stdenv,
  fetchurl,
  bash,
  goOS,
  goArch,
  version,
  sha256,
  reportedVersion,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "go-bootstrap";
  inherit version;
  src = fetchurl {
    url = "https://dl.google.com/go/go1.4-bootstrap-${version}.tar.gz";
    inherit sha256;
  };
  dontConfigure = true;
  GOOS = goOS;
  GOARCH = goArch;
  CGO_ENABLED = "0";
  buildPhase = ''
    runHook preBuild
    export GOROOT="$PWD"
    export GOROOT_FINAL="$out/share/go"
    cd src
    ${bash}/bin/bash ./make.bash
    cd ..
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/go" "$out/bin"
    cp -a . "$out/share/go/"
    ln -s ../share/go/bin/go "$out/bin/go"
    ln -s ../share/go/bin/gofmt "$out/bin/gofmt"
    runHook postInstall
  '';
  meta = {
    description = "Upstream C-based Go bootstrap compiler distribution";
    homepage = "https://go.dev/doc/install/source";
    license = lib.licenses.bsd3;
    platforms = [ "x86_64-linux" ];
    mainProgram = "go";
  };
  passthru = {
    tvp.deps = {
      inherit bash;
    };
    tvp.reportedVersion = reportedVersion;
    tvp.features.cgo = false;
    tests = mkTests finalAttrs.finalPackage;
  };
})

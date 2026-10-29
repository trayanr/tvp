# Source-built Go with an exact earlier compiler and native C toolchain.
{
  lib,
  stdenv,
  fetchurl,
  bootstrap,
  bash,
  goOS,
  goArch,
  dynamicLinker,
  version,
  sha256,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "go";
  inherit version;
  src = fetchurl {
    url = "https://dl.google.com/go/go${version}.src.tar.gz";
    inherit sha256;
  };
  dontConfigure = true;
  GOOS = goOS;
  GOARCH = goArch;
  GO_LDSO = "${stdenv.cc.libc}/${dynamicLinker}";
  CGO_ENABLED = "1";
  GOENV = "off";
  GOTOOLCHAIN = "local";
  GOPROXY = "off";
  GOSUMDB = "off";
  buildPhase = ''
    runHook preBuild
    export CC="${stdenv.cc}/bin/gcc" CXX="${stdenv.cc}/bin/g++"
    export GOROOT="$PWD"
    export GOROOT_FINAL="$out/share/go"
    export GOROOT_BOOTSTRAP="${bootstrap}/share/go"
    export GOCACHE="$TMPDIR/go-cache"
    export GOPATH="$TMPDIR/go-work"
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
    description = "Go compiler and standard library built from source";
    homepage = "https://go.dev/";
    license = lib.licenses.bsd3;
    platforms = [ "x86_64-linux" ];
    mainProgram = "go";
  };
  passthru = {
    tvp.deps = {
      inherit bootstrap bash;
    };
    tvp.cc = stdenv.cc;
    tvp.dynamicLinker = "${stdenv.cc.libc}/${dynamicLinker}";
    tvp.features.cgo = true;
    tvp.features.toolchainSelection = false;
    tests = mkTests finalAttrs.finalPackage;
  };
})

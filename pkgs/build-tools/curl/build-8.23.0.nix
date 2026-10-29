{
  lib,
  stdenv,
  fetchurl,
  pkg-config,
  patchelf,
  perl,
  python,
  openssl,
  zlib,
  zstd,
  nghttp2,
  ca-certificates,
  configureOptions,
  version,
  sha256,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "curl";
  inherit version;
  src = fetchurl {
    url = "https://curl.se/download/curl-${version}.tar.gz";
    inherit sha256;
  };
  nativeBuildInputs = [
    pkg-config
    patchelf
    perl
    python
  ];
  buildInputs = [
    openssl
    zlib
    zstd
    nghttp2
  ];
  preConfigure = ''
    patchShebangs scripts tests
    export PKG_CONFIG_PATH='${openssl}/lib/pkgconfig:${zlib}/lib/pkgconfig:${zstd}/lib/pkgconfig:${nghttp2}/lib/pkgconfig'
  '';
  configureFlags = [
    "--with-openssl=${openssl}"
    "--with-zlib=${zlib}"
    "--with-zstd=${zstd}"
    "--with-nghttp2=${nghttp2}"
    "--with-ca-bundle=${ca-certificates}/etc/ssl/certs/ca-bundle.crt"
    "--without-ca-path"
  ] ++ configureOptions;
  enableParallelBuilding = true;
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    make -C tests test TFLAGS='1 2 3 4 5 6 7 8 9 10'
    runHook postCheck
  '';
  postFixup = ''
    patchelf --shrink-rpath "$out/bin/curl"
    patchelf --shrink-rpath "$out/lib/libcurl.so"
  '';
  meta = {
    description = "URL transfer client and library with TLS, HTTP/2 and compression";
    homepage = "https://curl.se/";
    license = lib.licenses.curl;
    platforms = [ "x86_64-linux" ];
    mainProgram = "curl";
  };
  passthru = {
    tvp.deps = {
      inherit
        pkg-config
        patchelf
        perl
        python
        openssl
        zlib
        zstd
        nghttp2
        ca-certificates
        ;
    };
    tvp.cc = stdenv.cc;
    tvp.features = {
      tls = true;
      http2 = true;
      http3 = false;
      idn = false;
      publicSuffixList = false;
      ssh = false;
      brotli = false;
    };
    tests = mkTests finalAttrs.finalPackage;
  };
})

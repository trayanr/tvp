{
  lib,
  stdenv,
  fetchurl,
  patchelf,
  version,
  sha256,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "libdns_sd";
  inherit version;
  src = fetchurl {
    url = "https://github.com/apple-oss-distributions/mDNSResponder/archive/refs/tags/mDNSResponder-${version}.tar.gz";
    inherit sha256;
  };
  nativeBuildInputs = [ patchelf ];
  dontConfigure = true;
  buildPhase = ''
    runHook preBuild
    make -C mDNSPosix os=linux libdns_sd
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    install -Dm755 mDNSPosix/build/prod/libdns_sd.so "$out/lib/libdns_sd.so.1"
    ln -s libdns_sd.so.1 "$out/lib/libdns_sd.so"
    install -Dm644 mDNSShared/dns_sd.h "$out/include/dns_sd.h"
    install -Dm644 mDNSShared/dnssd_clientlib.c "$out/share/licenses/libdns_sd/dnssd_clientlib.c"
    runHook postInstall
  '';
  meta = {
    description = "mDNSResponder DNS Service Discovery client library";
    homepage = "https://github.com/apple-oss-distributions/mDNSResponder";
    license = lib.licenses.bsd3;
    platforms = [ "x86_64-linux" ];
  };
  passthru = {
    tvp.deps = {
      inherit patchelf;
    };
    tvp.cc = stdenv.cc;
    tvp.features.daemon = false;
    tests = mkTests finalAttrs.finalPackage;
  };
})

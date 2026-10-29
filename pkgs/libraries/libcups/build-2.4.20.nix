{
  lib,
  stdenv,
  fetchurl,
  pkg-config,
  openssl,
  zlib,
  dnssd,
  patchelf,
  version,
  sha256,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "libcups";
  inherit version;
  src = fetchurl {
    url = "https://github.com/OpenPrinting/cups/releases/download/v${version}/cups-${version}-source.tar.gz";
    inherit sha256;
  };
  nativeBuildInputs = [
    pkg-config
    patchelf
  ];
  buildInputs = [
    dnssd
    openssl
    zlib
  ];
  preConfigure = ''
    export PKG_CONFIG_PATH='${openssl}/lib/pkgconfig:${zlib}/lib/pkgconfig'
  '';
  configureFlags = [
    "--with-components=libcups"
    "--with-tls=openssl"
    "--with-dnssd=mdnsresponder"
    "--with-dnssd-includes=${dnssd}/include"
    "--with-dnssd-libs=${dnssd}/lib"
    "--disable-gssapi"
    "--disable-pam"
    "--disable-dbus"
    "--disable-libusb"
    "--disable-systemd"
    "--with-rcdir=no"
    "--with-rclevels=no"
  ];
  enableParallelBuilding = true;
  meta = {
    description = "CUPS client printing library with TLS support";
    homepage = "https://openprinting.github.io/cups/";
    license = lib.licenses.asl20;
    platforms = [ "x86_64-linux" ];
  };
  passthru = {
    tvp.deps = {
      inherit
        dnssd
        pkg-config
        openssl
        zlib
        patchelf
        ;
    };
    tvp.cc = stdenv.cc;
    tvp.features = {
      server = false;
      tls = true;
      discovery = true;
    };
    tests = mkTests finalAttrs.finalPackage;
  };
})

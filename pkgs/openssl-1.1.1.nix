{ lib, stdenv, fetchurl, perl }:

stdenv.mkDerivation rec {
  pname = "openssl";
  version = "1.1.1u"; 
  underscoreVersion = builtins.replaceStrings ["."] ["_"] version; # 1.1.1 to 1_1_1

  src = fetchurl {
	url = "https://github.com/openssl/openssl/releases/download/OpenSSL_${underscoreVersion}/${pname}-${version}.tar.gz";
    sha256 = "sha256-4vjYS1I+7NBse+diaDA3AwD7zBU4a/UULXJ1j2lj68Y=";
  };

  nativeBuildInputs = [ perl ];

  configureScript = "./config";

  configureFlags = [
    "shared"
    "--libdir=lib"
    "--openssldir=etc/ssl"
  ];

  installTargets = [ "install_sw" ];

  # Parallel building is not reliable in OpenSSL
  enableParallelBuilding = false;

  meta = with lib; {
    description = "A cryptographic library that implements the SSL and TLS protocols";
    homepage = "https://www.openssl.org/";
    license = licenses.openssl;
    platforms = platforms.all;
  };
}

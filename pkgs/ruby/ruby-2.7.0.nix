{ lib, stdenv, fetchurl, readline, zlib, gdbm, openssl }:

stdenv.mkDerivation rec {
  pname = "ruby";
  version = "2.7.0";

  src = fetchurl {
    url = "https://cache.ruby-lang.org/pub/ruby/2.7/ruby-${version}.tar.gz";
    sha256 = "sha256-jJmqk7Xi8byEN9G7vv0nsT52lAJTMfdyRdDAaO8fjL4=";
  };

  buildInputs = [ openssl readline zlib gdbm ];

  configureFlags = [
    "--enable-shared"
    "--with-openssl-dir=${openssl.dev}"
    "--with-readline-dir=${readline.dev}"
    "--with-zlib-dir=${zlib.dev}"
    "--with-gdbm-dir=${gdbm}"
  ];

  meta = with lib; {
    description = "The Ruby programming language";
    homepage = "https://www.ruby-lang.org/";
    license = licenses.ruby;
    platforms = platforms.unix;
  };
}

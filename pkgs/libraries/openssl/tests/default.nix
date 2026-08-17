# One suite, shared by every OpenSSL version. Never fork it per builder: a test
# that exists only for newer versions cannot detect drift in an older one.
# Guards select whole tests; they never edit a test body.
{
  pkgs,
  tvpLib,
  openssl,
}:
let
  # sha256("tvp"), first 16 hex characters.
  tvpDigest = "f6f6ead0bd85c312";
in
tvpLib.tests.mkSuite {
  inherit pkgs;
  package = openssl;

  tests = {
    version = {
      script = ''
        openssl version | awk '{ print $2 }'
      '';
      expected = openssl.version;
    };

    digest = {
      script = ''
        printf tvp | openssl dgst -sha256 | awk '{ print $NF }' | cut -c1-16
      '';
      expected = tvpDigest;
    };

    enc = {
      script = ''
        printf secret \
          | openssl enc -aes-256-cbc -pbkdf2 -pass pass:tvp \
          | openssl enc -d -aes-256-cbc -pbkdf2 -pass pass:tvp
      '';
      expected = "secret";
    };

    # Key generation, signing and verification — the asymmetric path, which
    # exercises far more of libcrypto than a digest does.
    rsa = {
      script = ''
        openssl genrsa -out key.pem 2048 2>/dev/null
        openssl rsa -in key.pem -pubout -out pub.pem 2>/dev/null
        printf tvp > msg.txt
        openssl dgst -sha256 -sign key.pem -out msg.sig msg.txt
        openssl dgst -sha256 -verify pub.pem -signature msg.sig msg.txt
      '';
      expected = "Verified OK";
    };

    # Headers and libraries work together. Ruby's openssl extension depends on
    # exactly this, so it is worth proving here rather than only downstream.
    compile = {
      script = ''
        cp ${./fixtures/digest.c} digest.c
        cc digest.c -lcrypto -o digest
        ./digest
      '';
      expected = tvpDigest;
      extraInputs = [ pkgs.stdenv.cc ];
    };

    # The .pc file is what downstream builds actually read.
    pkg-config = {
      script = ''
        pkg-config --modversion openssl
      '';
      expected = openssl.version;
      extraInputs = [ pkgs.pkg-config ];
    };
  };
}

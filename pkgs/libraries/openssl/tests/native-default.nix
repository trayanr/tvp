# One suite, shared by every OpenSSL version. Never fork it per builder: a test
# that exists only for newer versions cannot detect drift in an older one.
# Guards select whole tests; they never edit a test body.
{
  pkgs,
  builder,
  tvpLib,
  package,
}:

let
  openssl = package;
  pkg-config = package.tvp.deps.pkgConfig;
  # sha256("tvp") and sha1("tvp"), first 16 hex characters.
  tvpDigest = "f6f6ead0bd85c312";
  tvpSha1 = "52d3d1f5a23c79c8";

  features = openssl.passthru.tvp.features or { };
in
package.testContext.mkSuite {
  inherit package;
  tools = package.specification.environment.tools ++ [ package.tvp.deps.binutils ];
  libraries = [ package ];

  tests =
    # Universal: SHA-1 and the legacy enc KDF are the widest common ground,
    # working from 0.9.7 to 4.0. These are the tests that detect drift across
    # the whole catalogue, so they must not depend on anything era-specific.
    {
      version = {
        script = ''
          openssl version | awk '{ print $2 }'
        '';
        expected = openssl.version;
      };

      digest-sha1 = {
        script = ''
          printf tvp | openssl dgst -sha1 | awk '{ print $NF }' | cut -c1-16
        '';
        expected = tvpSha1;
      };

      # No -pbkdf2: that option arrived in 1.1.1. Newer releases warn about the
      # implicit KDF on stderr, which is why only stdout is compared.
      enc = {
        script = ''
          printf secret \
            | openssl enc -aes-256-cbc -pass pass:tvp 2>/dev/null \
            | openssl enc -d -aes-256-cbc -pass pass:tvp 2>/dev/null
        '';
        expected = "secret";
      };

      # The .pc file is what downstream builds actually read.
      pkg-config = {
        script = ''
          export PKG_CONFIG_LIBDIR=${openssl}/lib/pkgconfig:${openssl}/share/pkgconfig
          pkg-config --modversion openssl
        '';
        expected = openssl.version;

      };
    }

    # SHA-2 landed in 0.9.8, so 0.9.7 and earlier get the universal set only.
    // pkgs.lib.optionalAttrs (features.sha256 or false) {
      digest = {
        script = ''
          printf tvp | openssl dgst -sha256 | awk '{ print $NF }' | cut -c1-16
        '';
        expected = tvpDigest;
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

      };
    }

    // pkgs.lib.optionalAttrs (features.pbkdf2 or false) {
      enc-pbkdf2 = {
        script = ''
          printf secret \
            | openssl enc -aes-256-cbc -pbkdf2 -pass pass:tvp \
            | openssl enc -d -aes-256-cbc -pbkdf2 -pass pass:tvp
        '';
        expected = "secret";
      };
    };
}

// (
  if package.specification ? finalHelper then
    import ./ordinary-contract.nix { inherit package; }
  else
    import ./native-contract.nix { inherit package; }
)

// (
  if package.specification ? upstreamIsolation && (package.specification.doCheck or true) then
    {
      upstream = import ./upstream.nix {
        inherit package tvpLib;
        inherit (pkgs) lib;
        inherit builder;
      };
    }
  else
    { }
)

// (
  if
    (package ? specification)
    && (package.specification ? upstreamPlan)
    && (package.specification.upstreamCheck.enabled or true)
  then
    {
      # Independent native upstream registration.
      upstream = import ../native/upstream.nix { package = package; };
    }
  else
    { }
)

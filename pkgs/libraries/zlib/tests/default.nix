# One suite, shared by every zlib version. Never fork it per builder: a test
# that exists only for newer versions cannot detect drift in an older one.
# Guards select whole tests; they never edit a test body.
#
# zlib installs no executable, so every test compiles against the headers and
# links the library — which is also how every consumer uses it.
{
  pkgs,
  tvpLib,
  zlib,
}:
let
  message = "tvp preserves what other software is built on";
  tvpCrc32 = "85d9b6d2";

  cc = [ pkgs.stdenv.cc ];

  features = zlib.passthru.tvp.features or { };
in
tvpLib.tests.mkSuite {
  inherit pkgs;
  package = zlib;

  tests =
    {
      version = {
        script = ''
          cc ${./fixtures/version.c} -lz -o version
          ./version
        '';
        expected = zlib.version;
        extraInputs = cc;
      };

      # Paired with `version`: together they prove the installed header and the
      # installed library came from the same build.
      header-version = {
        script = ''
          cc ${./fixtures/header-version.c} -lz -o header-version
          ./header-version
        '';
        expected = zlib.version;
        extraInputs = cc;
      };

      compress = {
        script = ''
          cc ${./fixtures/roundtrip.c} -lz -o roundtrip
          ./roundtrip
        '';
        expected = message;
        extraInputs = cc;
      };

      crc32 = {
        script = ''
          cc ${./fixtures/crc.c} -lz -o crc
          ./crc
        '';
        expected = tvpCrc32;
        extraInputs = cc;
      };

      # The on-disk format, checked by a gzip that knows nothing about this build.
      gzip = {
        script = ''
          cc ${./fixtures/gz.c} -lz -o gz
          ./gz
          gzip -dc out.gz
        '';
        expected = "tvp";
        extraInputs = cc ++ [ pkgs.gzip ];
      };
    }

    // pkgs.lib.optionalAttrs (features.pkgConfig or false) {
      pkg-config = {
        script = ''
          pkg-config --modversion zlib
        '';
        expected = zlib.version;
        extraInputs = [ pkgs.pkg-config ];
      };
    }

    // pkgs.lib.optionalAttrs (features.static or false) {
      # The archive by path, so this cannot silently fall through to libz.so.
      static = {
        script = ''
          cc ${./fixtures/roundtrip.c} ${zlib}/lib/libz.a -o roundtrip-static
          ./roundtrip-static
        '';
        expected = message;
        extraInputs = cc;
      };
    };
}

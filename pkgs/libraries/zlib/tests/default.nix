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

  # 0.x names the archive libgz.a; from 1.0 it is libz.a.
  l = "-l" + (features.libName or "z");

  # 1.2.7.2 reports "1.2.7.2-motley"; every other release reports its own name.
  reported = zlib.passthru.tvp.reportedVersion or zlib.version;
in
tvpLib.tests.mkSuite {
  inherit pkgs;
  package = zlib;

  tests =
    {
      # Paired with `version`: together they prove the installed header and the
      # installed library came from the same build.
      header-version = {
        script = ''
          cc ${./fixtures/header-version.c} ${l} -o header-version
          ./header-version
        '';
        expected = reported;
        extraInputs = cc;
      };

      compress = {
        script = ''
          cc ${./fixtures/roundtrip.c} ${l} -o roundtrip
          ./roundtrip
        '';
        expected = message;
        extraInputs = cc;
      };

      crc32 = {
        script = ''
          cc ${./fixtures/crc.c} ${l} -o crc
          ./crc
        '';
        expected = tvpCrc32;
        extraInputs = cc;
      };

      # The on-disk format, checked by a gzip that knows nothing about this build.
      gzip = {
        script = ''
          cc ${./fixtures/gz.c} ${l} -o gz
          ./gz
          gzip -dc out.gz
        '';
        expected = "tvp";
        extraInputs = cc ++ [ pkgs.gzip ];
      };
    }

    // pkgs.lib.optionalAttrs (features.compress2 or true) {
      # The levelled form, which arrives at 1.0.8. Kept as its own test so the
      # older releases lose only this one rather than the whole roundtrip.
      compress-level = {
        script = ''
          cc ${./fixtures/roundtrip-level.c} ${l} -o roundtrip-level
          ./roundtrip-level
        '';
        expected = message;
        extraInputs = cc;
      };
    }

    // pkgs.lib.optionalAttrs (features.versionFunction or true) {
      # The runtime version, from the library. zlibVersion() arrives at 1.0.5;
      # before that only the header carries a version at all.
      version = {
        script = ''
          cc ${./fixtures/version.c} ${l} -o version
          ./version
        '';
        expected = reported;
        extraInputs = cc;
      };
    }

    // pkgs.lib.optionalAttrs (features.pkgConfig or false) {
      pkg-config = {
        script = ''
          pkg-config --modversion zlib
        '';
        expected = reported;
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

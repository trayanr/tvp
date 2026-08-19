# One suite, shared by every xz version. Never fork it per builder: a test that
# exists only for newer versions cannot detect drift in an older one. Guards
# select whole tests; they never edit a test body.
{
  pkgs,
  tvpLib,
  xz,
}:
let
  message = "tvp preserves what other software is built on";

  cc = [ xz.passthru.tvp.cc ];
  features = xz.passthru.tvp.features or { };
in
tvpLib.tests.mkSuite {
  inherit pkgs;
  package = xz;

  tests =
    {
      version = {
        script = ''
          cc ${./fixtures/version.c} -llzma -o version
          ./version
        '';
        expected = xz.version;
        extraInputs = cc;
      };

      compress = {
        script = ''
          cc ${./fixtures/roundtrip.c} -llzma -o roundtrip
          ./roundtrip
        '';
        expected = message;
        extraInputs = cc;
      };

      # The on-disk container, read back by an xz this build knows nothing about.
      format = {
        script = ''
          cc ${./fixtures/format.c} -llzma -o format
          ./format
          ${pkgs.xz}/bin/xz -dc out.xz
        '';
        expected = "tvp";
        extraInputs = cc;
      };

      cli = {
        script = ''
          printf 'tvp' | xz -c | xz -dc
        '';
        expected = "tvp";
      };

      pkg-config = {
        script = ''
          pkg-config --modversion liblzma
        '';
        expected = xz.version;
        extraInputs = [ pkgs.pkg-config ];
      };
    }

    // pkgs.lib.optionalAttrs (features.threaded or false) {
      threaded = {
        script = ''
          cc ${./fixtures/threaded.c} -llzma -pthread -o threaded
          ./threaded
        '';
        expected = message;
        extraInputs = cc;
      };
    };
}

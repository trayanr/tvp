# One suite, shared by every libyaml version. Never fork it per builder: a test
# that exists only for newer versions cannot detect drift in an older one.
# Guards select whole tests; they never edit a test body.
#
# libyaml installs no executable, so every test compiles against the header and
# links the library — which is also how every consumer uses it.
{
  pkgs,
  tvpLib,
  libyaml,
}:
let
  cc = [ libyaml.passthru.tvp.cc ];
  features = libyaml.passthru.tvp.features or { };
in
tvpLib.tests.mkSuite {
  inherit pkgs;
  package = libyaml;

  tests =
    {
      version = {
        script = ''
          cc ${./fixtures/version.c} -lyaml -o version
          ./version
        '';
        expected = libyaml.version;
        extraInputs = cc;
      };

      parse = {
        script = ''
          cc ${./fixtures/parse.c} -lyaml -o parse
          ./parse
        '';
        expected = "north star name tvp";
        extraInputs = cc;
      };

      emit = {
        script = ''
          cc ${./fixtures/emit.c} -lyaml -o emit
          ./emit
        '';
        expected = "tvp";
        extraInputs = cc;
      };
    }

    // pkgs.lib.optionalAttrs (features.document or false) {
      # The loader API, which builds a node tree rather than a stream of events.
      document = {
        script = ''
          cc ${./fixtures/document.c} -lyaml -o document
          ./document
        '';
        expected = "tvp";
        extraInputs = cc;
      };
    }

    // pkgs.lib.optionalAttrs (features.pkgConfig or false) {
      pkg-config = {
        script = ''
          pkg-config --modversion yaml-0.1
        '';
        expected = libyaml.version;
        extraInputs = [ pkgs.pkg-config ];
      };
    };
}

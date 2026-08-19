# One suite, shared by every gdbm version. Never fork it per builder: a test
# that exists only for newer versions cannot detect drift in an older one.
# Guards select whole tests; they never edit a test body.
{
  pkgs,
  tvpLib,
  gdbm,
}:
let
  cc = [ pkgs.stdenv.cc ];
in
tvpLib.tests.mkSuite {
  inherit pkgs;
  package = gdbm;

  tests = {
    # The library, not a CLI: 1.10 and older ship testgdbm, and gdbmtool only
    # arrives at 1.11.
    version = {
      script = ''
        cc ${./fixtures/version.c} -lgdbm -o version
        ./version | sed -n 's|.*version \([0-9.]*\)\..*|\1|p'
      '';
      expected = gdbm.version;
      extraInputs = cc;
    };

    store = {
      script = ''
        cc ${./fixtures/store.c} -lgdbm -o store
        ./store
      '';
      expected = "tvp";
      extraInputs = cc;
    };

    # Proves libgdbm_compat is built: ruby's ext/dbm links these entry points,
    # and a gdbm configured without them still builds and installs.
    ndbm = {
      script = ''
        cc ${./fixtures/ndbm.c} -lgdbm_compat -lgdbm -o ndbm
        ./ndbm
      '';
      expected = "tvp";
      extraInputs = cc;
    };

    # Consumers written against the traditional layout include <gdbm/gdbm.h>.
    include-layout = {
      script = ''
        cc ${./fixtures/layout.c} -lgdbm -o layout
        ./layout
      '';
      expected = "tvp";
      extraInputs = cc;
    };
  };
}

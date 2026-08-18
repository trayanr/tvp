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
    version = {
      script = ''
        gdbmtool --version | head -1 | awk '{ print $NF }'
      '';
      expected = gdbm.version;
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

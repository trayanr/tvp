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
  features = gdbm.passthru.tvp.features or { };

  # dbm and ndbm are split into libgdbm_compat at 1.8.1; below that they are
  # linked into libgdbm itself.
  compatFlag = if (features.compatLib or true) then "-lgdbm_compat " else "";
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
        # 1.8.2 and older print "This is GDBM version X, as of DATE"; from 1.8.3
        # it is "GDBM version X. DATE". The first version-shaped token is the
        # only thing both forms share.
        ./version | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1
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
        cc ${./fixtures/ndbm.c} ${compatFlag}-lgdbm -o ndbm
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

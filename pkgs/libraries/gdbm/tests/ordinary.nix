# One suite, shared by every gdbm version. Never fork it per builder: a test
# that exists only for newer versions cannot detect drift in an older one.
# Guards select whole tests; they never edit a test body.
{
  pkgs,
  tvp,
  tvpLib,
  package,
}:

let
  gdbm = package;
  pkg-config = package.tvp.deps.pkgConfig;

  features = gdbm.passthru.tvp.features or { };

  # dbm and ndbm are split into libgdbm_compat at 1.8.1; below that they are
  # linked into libgdbm itself.
  compatFlag = if (features.compatLib or true) then "-lgdbm_compat " else "";
in
package.testContext.mkSuite {
  inherit package;
  tools = package.specification.environment.tools ++ [ package.tvp.deps.binutils ];
  libraries = [ package ];

  tests = {
    # The library, not a CLI: 1.10 and older ship testgdbm, and gdbmtool only
    # arrives at 1.11.
    roundtrip = {
      script = ''
        cc -std=gnu17 ${./fixtures/roundtrip.c} -lgdbm -o roundtrip
        ./roundtrip
      '';
      expected = "write-reopen-fetch-delete";
    };
    static = {
      script = ''
        cc -std=gnu17 ${./fixtures/roundtrip.c} ${package}/lib/libgdbm.a -o roundtrip
        ./roundtrip
      '';
      expected = "write-reopen-fetch-delete";
    };
    static-compat = {
      script = ''
        cc -std=gnu17 ${./fixtures/ndbm.c} ${
          if features.compatLib then "${package}/lib/libgdbm_compat.a " else ""
        }${package}/lib/libgdbm.a -o ndbm
        ./ndbm
      '';
      expected = "tvp";
    };
    version = {
      script = ''
        cc ${./fixtures/version.c} -lgdbm -o version
        # 1.8.2 and older print "This is GDBM version X, as of DATE"; from 1.8.3
        # it is "GDBM version X. DATE". The first version-shaped token is the
        # only thing both forms share.
        ./version | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1
      '';
      expected = gdbm.version;

    };

    store = {
      script = ''
        cc ${./fixtures/store.c} -lgdbm -o store
        ./store
      '';
      expected = "tvp";

    };

    # Proves libgdbm_compat is built: ruby's ext/dbm links these entry points,
    # and a gdbm configured without them still builds and installs.
    ndbm = {
      script = ''
        # Historical ndbm headers declare f(); preserve the pre-C23 dialect.
        cc -std=gnu17 ${./fixtures/ndbm.c} ${compatFlag}-lgdbm -o ndbm
        ./ndbm
      '';
      expected = "tvp";

    };

    # Consumers written against the traditional layout include <gdbm/gdbm.h>.
    include-layout = {
      script = ''
        cc ${./fixtures/layout.c} -lgdbm -o layout
        ./layout
      '';
      expected = "tvp";

    };
  };
}

// import ../ordinary/contracts.nix { inherit tvp package; }

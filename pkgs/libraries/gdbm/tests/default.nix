# One installed suite for all GDBM procedures. Known failures remain in release status.
{
  package,
  lib,
  context,
}:
let
  gdbm = package;
  features = package.tvp.features;
  tools = package.specification.base.standardTools // {
    binutils = package.specification.base.compiler.bintools;
  };
  compatFlag = if features.compatLib then "-lgdbm_compat " else "";
in
(context.mkSuite {
  inherit package;
  tools = [
    tools.binutils
    tools.grep
  ];
  libraries = [ package ];
  tests =
    {

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
    }
    // lib.optionalAttrs package.specification.installedInterface.roundtrip {
      roundtrip = {
        script = ''
          cc -std=gnu17 ${./fixtures/roundtrip.c} -lgdbm -o roundtrip
          ./roundtrip
        '';
        expected = "write-reopen-fetch-delete";
      };

    }
    // lib.optionalAttrs (features.static && package.specification.installedInterface.roundtrip) {
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

    }
    // lib.optionalAttrs package.specification.installedInterface.cli {

      cli-reorganize = {
        script = ''
          printf 'store answer 42\nreorganize\nfetch answer\n' | gdbmtool -n roundtrip > cli.txt
          grep -F 42 cli.txt >/dev/null
          gdbm_dump roundtrip dump.txt
          gdbm_load dump.txt restored
          printf 'fetch answer\n' | gdbmtool restored > restored.txt
          grep -F 42 restored.txt >/dev/null
          test ! -e ${package}/lib/libgdbm.a
          test ! -e ${package}/lib/libgdbm_compat.a
          printf database-ok
        '';
        expected = "database-ok";
      };
    };
})
// lib.optionalAttrs package.specification.installedInterface.finalizerControls (
  import ../contracts.nix { inherit package lib context; }
)
//
  lib.optionalAttrs
    (package.specification ? upstreamPlan && package.specification.upstreamCheck.enabled)
    {
      upstream = context.mkUpstream { inherit package; };
    }

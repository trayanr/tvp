# One suite, shared by every sqlite version. Never fork it per builder: a test
# that exists only for newer versions cannot detect drift in an older one.
# Guards select whole tests; they never edit a test body.
{
  package,
  lib,
  context,
}:
let
  sqlite = package;
  nativeProfile = package.specification.installedInterface.nativeProfile;
  tools = (package.specification.base.standardTools or { }) // {
    binutils = package.specification.base.compiler.bintools;
  };
  deps = sqlite.passthru.tvp.deps or { };
  features = sqlite.passthru.tvp.features or { };
in
context.mkSuite {
  tools = package.specification.environment.tools ++ [ tools.binutils ];
  libraries = [ package ];
  package = sqlite;

  tests =
    {
      # The library, which is what every consumer links.
      version = {
        script = ''
          "$CC" ${./fixtures/version.c} -lsqlite3 -o version
          ./version
        '';
        expected = sqlite.passthru.tvp.reportedVersion or sqlite.version;
      };

      query = {
        script = ''
          "$CC" ${./fixtures/query.c} -lsqlite3 -o query
          ./query
        '';
        expected = "tvp";
      };

      # The shell is a second artifact, and the one people reach for by hand.
      cli = {
        script = ''
          printf "create table t(a);\ninsert into t values(%s);\nselect a from t;\n" "'tvp'" \
            | sqlite3 test.db
        '';
        expected = "tvp";
      };

      # The on-disk format, written by the library and read by the shell.
      file-format = {
        script = ''
          sqlite3 disk.db "create table t(a text); insert into t values('tvp');"
          sqlite3 disk.db "select a from t;"
        '';
        expected = "tvp";
      };
    }

    // lib.optionalAttrs (!nativeProfile) {
      indexed-integers = {
        script = ''
          "$CC" ${./fixtures/indexed-integers.c} -lsqlite3 -o indexed-integers
          ./indexed-integers
        '';
        expected = "indexed-integers";
      };

    }

    // lib.optionalAttrs (features.libVersionFunction or true) {
      # The function form; 3.0.0 to 3.0.7 expose only the global.
      libversion = {
        script = ''
          "$CC" ${./fixtures/libversion.c} -lsqlite3 -o libversion
          ./libversion
        '';
        expected = sqlite.passthru.tvp.reportedVersion or sqlite.version;
      };
    }

    // lib.optionalAttrs (features.prepareV2 or true) {
      # The prepared-statement API, which arrives at 3.3.9.
      prepare-v2 = {
        script = ''
          "$CC" ${./fixtures/prepare.c} -lsqlite3 -o prepare
          ./prepare
        '';
        expected = "tvp";
      };
    }

    // lib.optionalAttrs (features.pkgConfig or true) {
      pkg-config = {
        script = ''
          export PKG_CONFIG_LIBDIR=${sqlite}/lib/pkgconfig:${sqlite}/share/pkgconfig
          pkg-config --modversion sqlite3
        '';
        expected = sqlite.passthru.tvp.pkgConfigVersion or sqlite.version;
      };
    }

    // lib.optionalAttrs (deps ? readline) {
      # readline is auto-detected, so the shell builds fine without it and
      # quietly loses line editing.
      readline-linkage = {
        script = ''
          LD_TRACE_LOADED_OBJECTS=1 ${sqlite}/bin/sqlite3 | awk '/libreadline/ { print $3 }' \
            | grep -q "^${deps.readline.out}/" && printf linked
        '';
        expected = "linked";
      };
    };
}

// (
  if nativeProfile then
    import ./native-contract.nix { inherit package lib context; }
  else
    import ./ordinary-contract.nix { inherit package lib context; }
)

// (
  if nativeProfile then
    lib.optionalAttrs (package.specification.upstreamCheck.enabled or true) {
      upstream = import ./upstream-native.nix { inherit package lib context; };
    }
  else
    {
      upstream = import ./upstream.nix { inherit package lib context; };
    }
)

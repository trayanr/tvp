# One suite, shared by every sqlite version. Never fork it per builder: a test
# that exists only for newer versions cannot detect drift in an older one.
# Guards select whole tests; they never edit a test body.
{
  pkgs,
  tvpLib,
  sqlite,
}:
let
  cc = [ sqlite.passthru.tvp.cc ];
  deps = sqlite.passthru.tvp.deps or { };
  features = sqlite.passthru.tvp.features or { };
in
tvpLib.tests.mkSuite {
  inherit pkgs;
  package = sqlite;

  tests =
    {
      # The library, which is what every consumer links.
      version = {
        script = ''
          cc ${./fixtures/version.c} -lsqlite3 -o version
          ./version
        '';
        expected = sqlite.passthru.tvp.reportedVersion or sqlite.version;
        extraInputs = cc;
      };

      query = {
        script = ''
          cc ${./fixtures/query.c} -lsqlite3 -o query
          ./query
        '';
        expected = "tvp";
        extraInputs = cc;
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

    // pkgs.lib.optionalAttrs (features.libVersionFunction or true) {
      # The function form; 3.0.0 to 3.0.7 expose only the global.
      libversion = {
        script = ''
          cc ${./fixtures/libversion.c} -lsqlite3 -o libversion
          ./libversion
        '';
        expected = sqlite.passthru.tvp.reportedVersion or sqlite.version;
        extraInputs = cc;
      };
    }

    // pkgs.lib.optionalAttrs (features.prepareV2 or true) {
      # The prepared-statement API, which arrives at 3.3.9.
      prepare-v2 = {
        script = ''
          cc ${./fixtures/prepare.c} -lsqlite3 -o prepare
          ./prepare
        '';
        expected = "tvp";
        extraInputs = cc;
      };
    }

    // pkgs.lib.optionalAttrs (features.pkgConfig or true) {
      pkg-config = {
        script = ''
          pkg-config --modversion sqlite3
        '';
        expected = sqlite.passthru.tvp.pkgConfigVersion or sqlite.version;
        extraInputs = [ pkgs.pkg-config ];
      };
    }

    // pkgs.lib.optionalAttrs (deps ? readline) {
      # readline is auto-detected, so the shell builds fine without it and
      # quietly loses line editing.
      readline-linkage = {
        script = ''
          ldd ${sqlite}/bin/sqlite3 | awk '/libreadline/ { print $3 }' \
            | grep -q "^${deps.readline.out}/" && printf linked
        '';
        expected = "linked";
        extraInputs = [ pkgs.glibc.bin ];
      };
    };
}

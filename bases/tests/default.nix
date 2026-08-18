# One suite, shared by every base. Never fork it per base: a test that exists
# only for newer substrate cannot detect drift in older substrate.
{ tvpLib, base }:
tvpLib.bases.mkBaseSuite {
  inherit base;

  tests = {
    # The compiler a build actually gets is the one the base is named for.
    cc-version = {
      script = "cc -dumpversion | cut -d. -f1";
      expected = base.cc;
    };

    compile = {
      script = ''
        cc ${./fixtures/libc.c} -o libc
        ./libc
      '';
      expected = "45";
    };

    # One representative binary per floor package. `command -v` alone would pass
    # for a path that is not runnable.
    floor = {
      script = ''
        for t in cp find diff sed grep awk tar gzip bzip2 make bash patch xz file; do
          $t --version > /dev/null 2>&1 || { echo "not runnable: $t"; exit 0; }
        done
        echo ok
      '';
      expected = "ok";
    };
  };
}

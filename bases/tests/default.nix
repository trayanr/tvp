# One suite, shared by every base. Never fork it per base: a test that exists
# only for newer substrate cannot detect drift in older substrate.
{ tvpLib, base }:
tvpLib.bases.mkBaseSuite {
  inherit base;

  tests = {
    # Not -dumpversion: it prints the full version before gcc 7 and the major
    # after it, so neither form is comparable across the catalogue.
    cc-version = {
      script = "cc --version | head -1 | grep -oE '[0-9]+\\.[0-9]+\\.[0-9]+'";
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

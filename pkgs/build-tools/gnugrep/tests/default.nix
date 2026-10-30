{
  pkgs,
  tvpLib,
  package,
  locale,
}:
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests = {
    version = {
      script = ''
        ${package}/bin/grep --version | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?'
      '';
      expected = package.version;
    };
    operation = {
      script = ''
        printf 'release-42\nrelease-no\n' | ${package}/bin/grep -Po '(?<=release-)[0-9]+'
      '';
      expected = "42";
    };
    pcre-utf8 = {
      script = ''
        unset LOCALE_ARCHIVE
        export LOCPATH=${locale}/lib/locale LC_ALL=C.UTF-8
        test "$(${locale.bin}/bin/locale charmap)" = UTF-8
        printf 'release-42\nrelease-no\n' | ${package}/bin/grep -Po '(?<=release-)[0-9]+'
        printf '3\n٣\n' > digits
        ${package}/bin/grep -P '^\d$' digits
        ${package}/bin/grep -P '^[[:digit:]]$' digits
      '';
      expected = "42\n3\n3\n٣";
    };
    max-count-overread = {
      script = ''
        printf 'x\nx\nx-third\n' > input
        (${package}/bin/grep -m2 x > /dev/null && head -n1) < input
      '';
      # Preserve the historical 3.11 overread rather than backporting a fix.
      expected = if pkgs.lib.versionOlder package.version "3.12" then "" else "x-third";
    };
    unix-byte-offsets = {
      script = ''
        export LC_ALL=C
        for option in -u --unix-byte-offsets; do
          status=0
          printf 'x\n' | ${package}/bin/grep "$option" x > actual-output 2> diagnostic || status=$?
          ${
            if pkgs.lib.versionOlder package.version "3.12" then
              ''
                test "$status" = 0
                test "$(cat actual-output)" = x
                grep -q 'warning:.*obsolete' diagnostic
              ''
            else
              ''
                test "$status" = 2
                test ! -s actual-output
                grep -q '^Usage:' diagnostic
                if test "$option" = --unix-byte-offsets; then
                  grep -q "unrecognized option '--unix-byte-offsets'" diagnostic
                fi
              ''
          }
        done
        echo ok
      '';
      expected = "ok";
    };
  };
}

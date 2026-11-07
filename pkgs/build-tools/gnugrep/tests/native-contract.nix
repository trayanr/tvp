{ package }:
let d = package.tvp.deps; in
package.testContext.mkSuite {
  inherit package;
  tools = package.specification.environment.tools ++ [ d.binutils ];
  tests.pcre-linkage = {
    script = ''
      LD_DEBUG=libs ${package}/bin/grep --version >/dev/null 2> loaded
      grep -F 'calling init: ${d.pcre2}/lib/libpcre2-8.so.0' loaded >/dev/null
      printf 'baba\n' | ${package}/bin/grep -Po '(?<=ba)ba' > actual
      test "$(cat actual)" = ba
      test -x ${package}/bin/egrep; test -x ${package}/bin/fgrep
      echo selected-pcre2
    '';
    expected = "selected-pcre2";
  };
}

{
  pkgs,
  tvpLib,
  package,
  locale,
}:
package.testContext.mkSuite {
  inherit package;
  tools = package.specification.environment.tools ++ [ package.tvp.declaredDependencies.binutils ];
  tests = {
    stdbuf = {
      tools = package.specification.environment.tools ++ [ package.tvp.cc ];
      script = ''
        cat > buffering.c <<'C'
        #include <stdio.h>
        #include <stdlib.h>
        int main(void) { fputs("buffered", stdout); _Exit(0); }
        C
        "$CC" buffering.c -o buffering
        ./buffering > without
        test ! -s without
        LD_DEBUG=libs ${package}/bin/stdbuf -o0 ./buffering > with 2> loader
        test "$(cat with)" = buffered
        grep -F 'calling init: ${package}/libexec/coreutils/libstdbuf.so' loader >&2
        echo installed-stdbuf-helper
      '';
      expected = "installed-stdbuf-helper";
    };
    version = {
      script = ''
        ${package}/bin/sort --version | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?'
      '';
      expected = package.version;
    };
    operation = {
      script = ''
        printf 'b\na\nb\n' | ${package}/bin/sort -u
        ${package}/bin/factor 18446744073709551617
      '';
      expected = "a\nb\n18446744073709551617: 274177 67280421310721";
    };
  };
}

// import ../../../../lib/tests/command-nls.nix {
  inherit package locale;
  command = "sort";
}

// import ../../../../lib/tests/command-acl.nix {
  inherit package;
  operation = ''
    ${package}/bin/cp -p sample copy
    mv copy sample
  '';
}

# Exercise selected executable drivers; metadata equality alone cannot prove that
# the owned environments compile, link and execute against their chosen libc.
{ tvp }:
let
  tests = builtins.mapAttrs (
    name: base:
    let
      context = tvp.lib.tests.forBase {
        builder = tvp.builder;
        inherit base;
        coreutils = base.tools.coreutils;
      };
    in
    context.mkTest {
      package = base.tools.gcc;
      name = "gcc13-${name}-context";
      script =
        ''
          "$CC" -x c -o context-c - <<'C'
          #include <stdio.h>
          int main(void) { puts("C"); return 0; }
          C
          test "$(./context-c)" = C
        ''
        + (
          if name == "full" then
            ''
              "$CXX" -x c++ -o context-cxx - <<'CXX'
              #include <iostream>
              #include <vector>
              int main() { std::vector<int> xs{1,2,3}; std::cout << xs.size(); }
              CXX
              test "$(./context-cxx)" = 3
            ''
          else
            ""
        )
        + ''
          printf '%s\n' context-ok
        '';
      expected = "context-ok";
    }
  ) tvp.bases.gcc_13;
  context = tvp.lib.tests.forBase {
    builder = tvp.builder;
    base = tvp.bases.gcc_13.full;
    coreutils = tvp.bases.gcc_13.full.tools.coreutils;
  };
in
context.mkBatch {
  name = "gcc13-stage-contexts";
  suite = tests;
}

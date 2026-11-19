{
  package,
  context,
  ...
}:
context.mkSuite {
  inherit package;
  tests.archive = {
    script = ''
      test -f "${package}/include/c-client/c-client.h"
      test -f "${package}/include/c-client/linkage.c"
      test -s "${package}/lib/libc-client.a"
    '';
    expected = "";
  };
}

{
  pkgs,
  tvpLib,
  package,
}:
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests = {
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

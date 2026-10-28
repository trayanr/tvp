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
        ${package}/bin/diff --version | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?'
      '';
      expected = package.version;
    };
    operation = {
      script = ''
        printf 'before\n' > before; printf 'after\n' > after
        status=0
        ${package}/bin/diff --old-line-format='-%L' --new-line-format='+%L' before after || status=$?
        test "$status" = 1
        ${package}/bin/cmp before before
      '';
      expected = "-before\n+after";
    };
    pagination = {
      script = ''
        printf 'before\n' > before
        printf 'after\n' > after
        status=0
        ${package}/bin/diff -l before after > paginated || status=$?
        test "$status" = 1
        grep '^< before$' paginated
      '';
      expected = "< before";
    };
  };
}

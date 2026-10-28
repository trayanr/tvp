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
        ${package}/bin/gzip --version | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?'
      '';
      expected = package.version;
    };
    operation = {
      script = ''
        printf preserved | ${package}/bin/gzip -n > sample.gz
        ${package}/bin/gzip -t sample.gz
        ${package}/bin/gzip -dc sample.gz
      '';
      expected = "preserved";
    };
    zgrep = {
      script = ''
        printf 'before\npreserved\nafter\n' | ${package}/bin/gzip -n > lines.gz
        ${package}/bin/zgrep '^preserved$' lines.gz
      '';
      expected = "preserved";
    };
  };
}

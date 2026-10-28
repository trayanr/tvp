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
        ${package}/bin/bzip2 --help 2>&1 | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?'
      '';
      expected = package.version;
    };
    operation = {
      script = ''
        printf preserved | ${package}/bin/bzip2 > sample.bz2
        ${package}/bin/bzip2 -t sample.bz2
        ${package}/bin/bzip2 -dc sample.bz2
      '';
      expected = "preserved";
    };
  };
}

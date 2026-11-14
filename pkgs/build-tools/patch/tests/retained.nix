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
        ${package}/bin/patch --version | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?'
      '';
      expected = package.version;
    };
    operation = {
      script = ''
        printf 'before\n' > sample
        printf '%s\n' '--- sample' '+++ sample' '@@ -1 +1 @@' '-before' '+after' > changes
        ${package}/bin/patch -s -p0 < changes
        cat sample
      '';
      expected = "after";
    };
  };
}

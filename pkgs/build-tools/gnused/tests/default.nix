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
        ${package}/bin/sed --version | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | sed -n '1p'
      '';
      expected = package.version;
    };
    operation = {
      script = ''
        printf 'old old\n' > sample
        ${package}/bin/sed -i 's/old/new/g' sample
        cat sample
      '';
      expected = "new new";
    };
  };
}

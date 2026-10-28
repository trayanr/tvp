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
        ${package}/bin/pcre2grep --version | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?'
      '';
      expected = package.version;
    };
    operation = {
      script = ''
        printf 'preserved-42\n' | ${package}/bin/pcre2grep -o '[a-z]+(?=-[0-9]+)'
      '';
      expected = "preserved";
    };
  };
}

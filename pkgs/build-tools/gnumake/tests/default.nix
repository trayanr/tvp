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
        ${package}/bin/make --version | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?'
      '';
      expected = package.version;
    };
    operation = {
      script = ''
        printf 'all: a b\na b:\n\t@echo $@\n' > Makefile
        ${package}/bin/make --no-print-directory -j2 --output-sync=target | sort
      '';
      expected = "a\nb";
    };
  };
}

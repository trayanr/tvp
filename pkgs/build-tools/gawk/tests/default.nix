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
        ${package}/bin/gawk --version | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | sed -n '1p'
      '';
      expected = package.version;
    };
    operation = {
      script = ''
        ${package}/bin/gawk -M 'BEGIN { printf "%d\n", 2^128 }'
      '';
      expected = "340282366920938463463374607431768211456";
    };
  };
}

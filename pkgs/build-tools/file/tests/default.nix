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
        ${package}/bin/file --version | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?'
      '';
      expected = package.version;
    };
    operation = {
      script = ''
        printf '#!/bin/sh\necho preserved\n' > sample.sh
        ${package}/bin/file --mime-type -b sample.sh
      '';
      expected = "text/x-shellscript";
    };
  };
}

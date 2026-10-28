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
        ${package}/bin/bash --version | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?'
      '';
      expected = package.version;
    };
    operation = {
      script = ''
        ${package}/bin/bash --noprofile --norc -c 'set -euo pipefail; declare -A names=([tvp]=preserved); mapfile -t lines < <(printf "%s\n" "''${names[tvp]}"); printf "%s\n" "''${lines[0]}"'
      '';
      expected = "preserved";
    };
  };
}

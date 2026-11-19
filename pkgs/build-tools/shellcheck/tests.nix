{ package, context, ... }:
context.mkSuite {
  inherit package;
  tests = {
    version = {
      script = ''
        version_output=$(${package}/bin/shellcheck --version)
        while IFS= read -r line; do
          if [[ "$line" == 'version: '* ]]; then
            printf '%s\n' "''${line#version: }"
          fi
        done <<< "$version_output"
      '';
      expected = package.version;
    };
    lint = {
      script = ''
        printf '%s\n' '#!/bin/bash' 'printf "%s\n" "$1"' > valid.sh
        printf '%s\n' '#!/bin/bash' 'echo $1' > invalid.sh
        ${package}/bin/shellcheck valid.sh
        status=0
        report=$(${package}/bin/shellcheck --format=gcc invalid.sh) || status=$?
        [[ "$status" -eq 1 && "$report" == *'[SC2086]'* ]]
        printf '%s\n' 'SC2086'
      '';
      expected = "SC2086";
    };
  };
}

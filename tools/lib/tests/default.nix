{
  pkgs,
  tvp,
  ownedCLI,
}:
let
  shell = ownedCLI.shell {
    name = "tvp-cli-shell-probe";
    runtimeInputs = [
      tvp.packages.coreutils
      tvp.packages.gnused
    ];
    text = ''
      printf '%s\n' "$PATH"
      printf '<%s>\n' "$@"
      case "$1" in
        pipe) false | true ;;
        unset) echo "$TVP_INTENTIONALLY_UNSET" ;;
        fail) false; echo unreachable ;;
      esac
    '';
  };
  python = ownedCLI.python {
    name = "tvp-cli-python-probe";
    python3 = tvp.packages.python_3;
    files."probe.py" = ./probe.py;
    entrypoint = "probe.py";
    systemVariable = "TVP_TEST_SYSTEM";
  };
in
pkgs.runCommand "tvp-cli-packaging-contracts" { nativeBuildInputs = [ tvp.packages.python_3 ]; } ''
  python3 ${./contracts.py} ${shell}/bin/tvp-cli-shell-probe \
    ${python}/bin/tvp-cli-python-probe \
    ${
      pkgs.lib.escapeShellArg (
        pkgs.lib.makeBinPath [
          tvp.packages.coreutils
          tvp.packages.gnused
        ]
      )
    } \
    ${tvp.bases.default.platform.system}
  printf '%s\n' 'CLI argument, PATH, strict-mode, environment, exec, signal and exit contracts passed.' > "$out"
''

#!/usr/bin/env bash
# A foreground CI entry point around the existing frozen-plan runner.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
state_dir=${1:-.tvp-tests/ci}
# Record generated producer inputs before the read-only flake check.
nix eval --show-trace --json .#graph > /dev/null
nix flake check --show-trace --no-build
launch_file=$(mktemp)
trap 'rm -f "$launch_file"' EXIT
nix run --show-trace .#test -- start --state-dir "$state_dir" --json > "$launch_file"
run=$(TVP_CI_START="$launch_file" nix eval --show-trace --impure --raw --expr \
    '(builtins.fromJSON (builtins.readFile (builtins.getEnv "TVP_CI_START"))).run')
runner="$run/runner/bin/tvp-test"
status=0
"$runner" wait --run "$run" || status=$?
"$runner" status --run "$run" --json > "$run/ci-status.json"
printf 'CI artifacts: %s\n' "$run"
exit "$status"

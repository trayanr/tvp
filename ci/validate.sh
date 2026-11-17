#!/usr/bin/env bash
# A foreground smoke-check entry point around the existing frozen-plan runner.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
state_dir=${1:-.tvp-tests/ci}
# Record generated producer inputs before the read-only flake check.
nix eval --show-trace --json .#graph > /dev/null
nix flake check --show-trace --no-build
exec nix run --show-trace .#test -- all --smoke --state-dir "$state_dir"

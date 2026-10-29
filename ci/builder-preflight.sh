#!/usr/bin/env bash
# Read-only inventory, intended to run on the proposed Linux builder.
set -euo pipefail

if [[ $(uname -s) != Linux || $(uname -m) != x86_64 ]]; then
    echo 'The currently validated TVP builder target is x86_64 Linux.' >&2
    exit 1
fi
printf 'Architecture: %s\n' "$(uname -m)"
if [[ -r /etc/os-release ]]; then
    (source /etc/os-release; printf 'Distribution: %s\n' "$PRETTY_NAME")
fi
printf 'Logical CPUs: %s\n' "$(getconf _NPROCESSORS_ONLN)"
awk '/^MemTotal:/ {printf "Memory: %.1f GiB\n", $2/1024/1024}' /proc/meminfo
if ! command -v nix >/dev/null; then
    echo 'Nix is not installed or is absent from this shell PATH.' >&2
    exit 1
fi
nix --version
# Query individual settings; a full configuration dump can expose access tokens.
for setting in system sandbox max-jobs cores experimental-features; do
    printf '%s: %s\n' "$setting" "$(nix config show "$setting")"
done
df -h /nix/store
if [[ -r /dev/kvm && -w /dev/kvm ]]; then
    echo 'KVM: accessible to this user'
else
    echo 'KVM: unavailable to this user (needed for the later isolated PR workers)'
fi

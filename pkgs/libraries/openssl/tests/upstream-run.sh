# Preserve the full native serial workload and its exit status.
set -eu
make=$1
shell=$2
perl=$3
exec "$make" -j1 "SHELL=$shell" "PERL=$perl" test

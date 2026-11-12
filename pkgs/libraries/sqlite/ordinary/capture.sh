# Raw execution only. The registered upstream test classifier owns acceptance.
# stdout/stderr are retained byte-for-byte; a failed intermediate is unqualified.
set -eu
receipt=$1
shift
mkdir -p "$receipt"
set +e
"$@" > "$receipt/output" 2>&1
result=$?
set -e
printf '%s\n' "$result" > "$receipt/exit"
cat "$receipt/output"

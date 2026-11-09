# Called with the selected Bash and explicit inspection tools.
set -euo pipefail

reader=$1
matcher=$2
binary=$3
library=$4

# A failed reader must stop the test before absence can be inferred.
dynamic=$("$reader" -d "$binary")
if "$matcher" -F -- "Shared library: [$library" <<< "$dynamic"; then
    printf 'Archive consumer also links shared target %s\n' "$library" >&2
    exit 1
else
    status=$?
    # Grep defines 1 as absence; every other nonzero status is an error.
    if [[ $status != 1 ]]; then exit "$status"; fi
fi

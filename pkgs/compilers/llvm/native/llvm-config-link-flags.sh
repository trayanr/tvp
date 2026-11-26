set -euo pipefail

for argument in "$@"; do
    [[ "$argument" == --ldflags ]] || continue
    "$llvm_config" "$@" | while IFS= read -r line; do
        case "$line" in
            "-L$llvm_libdir "*) printf '%s %s\n' "$line" "$llvm_link_flag" ;;
            *) printf '%s\n' "$line" ;;
        esac
    done
    exit
done

exec "$llvm_config" "$@"

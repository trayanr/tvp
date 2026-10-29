# SDKs keep writable locks and caches. Publish a complete per-output copy
# atomically so concurrent first invocations never observe a partial tree.
prepareWritableSdk() (
    set -e
    local source=$1 cache_root=$2 identity=$3 cache temporary
    cache="$cache_root/$identity"
    if ! test -f "$cache/.tvp-prepared"; then
        mkdir -p "$cache_root"
        temporary=$(mktemp -d "$cache_root/.prepare.XXXXXXXX")
        trap 'rm -rf "$temporary"' EXIT
        # Preserve timestamps: Flutter uses pubspec/lock mtimes to decide
        # whether its already-built tool snapshot needs regeneration.
        cp -rp --reflink=auto "$source/." "$temporary/"
        chmod -R u+w "$temporary"
        touch "$temporary/.tvp-prepared"
        if ! mv -T "$temporary" "$cache"; then
            test -f "$cache/.tvp-prepared"
        fi
    fi
    printf '%s\n' "$cache"
)

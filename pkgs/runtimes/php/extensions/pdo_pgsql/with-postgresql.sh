set -euo pipefail

postgresql=$1
shift
fixture=$(mktemp -d "${TMPDIR:-/tmp}/tvp-pg.XXXXXXXX")
cleanup() {
    status=$?
    if [[ -e "$fixture/data/postmaster.pid" ]]; then
        "$postgresql/bin/pg_ctl" -D "$fixture/data" -w -t 10 -m immediate stop >&2 || true
    fi
    if (( status != 0 )); then
        for log in "$fixture/init.log" "$fixture/server.log"; do
            if [[ -f "$log" ]]; then cat "$log" >&2; fi
        done
    fi
    rm -rf -- "$fixture"
}
trap cleanup EXIT

timeout 30 "$postgresql/bin/initdb" -D "$fixture/data" --no-locale -E UTF8 \
    -U tvp_smoke -A trust > "$fixture/init.log" 2>&1
"$postgresql/bin/pg_ctl" -D "$fixture/data" -l "$fixture/server.log" -w -t 15 \
    -o "-c listen_addresses='' -k '$fixture'" start >&2

TVP_POSTGRES_SOCKET="$fixture" timeout 15 "$@"

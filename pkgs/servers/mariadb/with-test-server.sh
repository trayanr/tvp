set -euo pipefail

server=$1
shift
fixture=$(mktemp -d "${TMPDIR:-/tmp}/tvp-mysql.XXXXXXXX")
socket="$fixture/db.sock"
server_pid=

cleanup() {
    status=$?
    if [[ -n "$server_pid" ]]; then
        kill "$server_pid" 2>/dev/null || true
        wait "$server_pid" 2>/dev/null || true
    fi
    if (( status != 0 )); then
        for log in "$fixture/install.log" "$fixture/server.log" "$fixture/setup.log"; do
            if [[ -f "$log" ]]; then cat "$log" >&2; fi
        done
    fi
    rm -rf -- "$fixture"
}
trap cleanup EXIT

# Use a dedicated account and schema inside the disposable data directory.
cat > "$fixture/setup.sql" <<'SQL'
CREATE DATABASE tvp_smoke;
CREATE USER 'tvp_smoke'@'localhost' IDENTIFIED BY 'tvp-local-fixture';
GRANT SELECT, INSERT, CREATE TEMPORARY TABLES ON tvp_smoke.* TO 'tvp_smoke'@'localhost';
SQL

timeout 60 "$server/bin/mariadb-install-db" --no-defaults \
    --basedir="$server" --datadir="$fixture/data" --skip-test-db --force \
    --skip-name-resolve --skip-networking --socket="$socket" \
    --auth-root-authentication-method=normal \
    --innodb-buffer-pool-size=16M > "$fixture/install.log" 2>&1

"$server/bin/mariadbd" --no-defaults --basedir="$server" --datadir="$fixture/data" \
    --skip-networking --skip-name-resolve --skip-log-bin \
    --innodb-buffer-pool-size=16M --max-connections=8 \
    --socket="$socket" --pid-file="$fixture/db.pid" > "$fixture/server.log" 2>&1 &
server_pid=$!

ready=false
deadline=$((SECONDS + 15))
while (( SECONDS < deadline )); do
    if [[ -S "$socket" ]] && timeout 2 "$server/bin/mariadb-admin" --no-defaults \
        --protocol=socket --socket="$socket" --connect-timeout=1 \
        --user=root ping >/dev/null 2>&1; then
        ready=true
        break
    fi
    kill -0 "$server_pid"
    sleep 0.05
done
if ! "$ready"; then
    echo 'MariaDB fixture did not become ready' >&2
    exit 1
fi

# Bootstrap runs with grant tables disabled. Create the test account after
# startup, through the private socket inside the mode-0700 fixture directory.
timeout 15 "$server/bin/mariadb" --no-defaults --protocol=socket \
    --socket="$socket" --user=root < "$fixture/setup.sql" > "$fixture/setup.log" 2>&1

TVP_MYSQL_SOCKET="$socket" timeout 30 "$@"

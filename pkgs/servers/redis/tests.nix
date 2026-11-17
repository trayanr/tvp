{
  package,
  lib,
  context,
}:
context.mkSuite {
  inherit package;
  tools = [ ];
  libraries = [ ];
  tests = {
    version = {
      script = ''
        server=$(redis-server --version)
        case "$server" in
          ${lib.escapeShellArg "Redis server v=${package.version} "}*) ;;
          *) printf '%s\n' "$server" >&2; exit 1 ;;
        esac
        test "$(redis-cli --version)" = ${lib.escapeShellArg "redis-cli ${package.version}"}
        printf '%s' ${lib.escapeShellArg package.version}
      '';
      expected = package.version;
    };
    roundtrip = {
      script = ''
        socket="$PWD/redis.sock"
        redis-server --port 0 --unixsocket "$socket" --unixsocketperm 700 \
          --save "" --appendonly no --daemonize no --dir "$PWD" \
          --logfile "$PWD/redis.log" > redis.stdout 2>&1 &
        server_pid=$!
        cleanup() {
          kill "$server_pid" 2>/dev/null || true
          wait "$server_pid" 2>/dev/null || true
        }
        trap cleanup EXIT
        for attempt in {1..100}; do
          if test -S "$socket"; then break; fi
          if ! kill -0 "$server_pid" 2>/dev/null; then
            cat redis.stdout redis.log >&2
            exit 1
          fi
          sleep 0.05
        done
        test -S "$socket"
        test "$(redis-cli -s "$socket" ping)" = PONG
        test "$(redis-cli -s "$socket" set tvp-smoke stored)" = OK
        test "$(redis-cli -s "$socket" --raw get tvp-smoke)" = stored
        printf 'PONG SET GET'
      '';
      expected = "PONG SET GET";
    };
  };
}

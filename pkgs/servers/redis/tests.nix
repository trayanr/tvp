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
    tls-compression = {
      tools = [
        package.specification.openssl
        package.specification.base.tools.python
      ];
      script = ''
        openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj /CN=localhost \
          -addext 'subjectAltName=DNS:localhost,IP:127.0.0.1' \
          -keyout key.pem -out cert.pem > cert.log 2>&1 || {
            cat cert.log >&2
            exit 1
          }
        port=$(python3 - <<'PY'
        import socket

        with socket.socket() as listener:
            listener.bind(("127.0.0.1", 0))
            print(listener.getsockname()[1])
        PY
        )
        redis-server --bind 127.0.0.1 --port 0 --tls-port "$port" \
          --tls-cert-file "$PWD/cert.pem" --tls-key-file "$PWD/key.pem" \
          --tls-ca-cert-file "$PWD/cert.pem" --tls-auth-clients yes \
          --save "" --appendonly no --daemonize no --dir "$PWD" \
          --io-threads 2 --repl-compression 1 > redis.log 2>&1 &
        server_pid=$!
        cleanup() {
          kill "$server_pid" 2>/dev/null || true
          wait "$server_pid" 2>/dev/null || true
        }
        trap cleanup EXIT
        client() {
          redis-cli --tls -h 127.0.0.1 -p "$port" --cacert "$PWD/cert.pem" \
            --cert "$PWD/cert.pem" --key "$PWD/key.pem" --raw "$@"
        }
        reply=
        for attempt in {1..100}; do
          reply=$(client ping 2> client.log) && test "$reply" = PONG && break
          if ! kill -0 "$server_pid" 2>/dev/null; then break; fi
          sleep 0.05
        done
        if test "$reply" != PONG; then
          cat redis.log client.log >&2
          exit 1
        fi
        test "$(client set tvp-tls-smoke encrypted)" = OK
        test "$(client get tvp-tls-smoke)" = encrypted
        test "$(client config get repl-compression)" = "$(printf 'repl-compression\n1')"
        printf 'TLS PONG SET GET and replication compression enabled'
      '';
      expected = "TLS PONG SET GET and replication compression enabled";
    };
  };
}

{ tvp }:
{
  package,
  lib,
  context,
}:
let
  runtime = import ../../with-extensions.nix {
    inherit lib tvp;
    php = package.php;
    extensions = [ package ];
    settings.memory_limit = "128M";
  };
  server = package.tvp.declaredTestDependencies.redis;
in
context.mkSuite {
  inherit package;
  tools = [
    runtime
    server
  ];
  tests = {
    load = {
      script = ''${runtime}/bin/php -r 'echo phpversion("redis");' '';
      expected = package.version;
    };
    roundtrip = {
      script = ''
        socket="$PWD/redis.sock"
        ${server}/bin/redis-server --port 0 --unixsocket "$socket" \
          --unixsocketperm 700 --save "" --appendonly no > server.log 2>&1 &
        server_pid=$!
        trap 'kill "$server_pid" 2>/dev/null || true; wait "$server_pid" 2>/dev/null || true' EXIT
        for attempt in $(seq 1 100); do
          if [ -S "$socket" ]; then break; fi
          kill -0 "$server_pid" || { cat server.log >&2; exit 1; }
          sleep 0.05
        done
        REDIS_SOCKET="$socket" ${runtime}/bin/php -r '
          $r = new Redis();
          if (!$r->connect(getenv("REDIS_SOCKET"))) { exit(1); }
          if (!$r->set("tvp-smoke", "php-redis-roundtrip")) { exit(2); }
          echo $r->get("tvp-smoke");
          $r->close();
        '
      '';
      expected = "php-redis-roundtrip";
    };
  };
}

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
in
context.mkSuite {
  inherit package;
  tools = [ runtime ];
  tests = {
    load = {
      script = ''
        ${runtime}/bin/php -r '
          if (!in_array("dblib", PDO::getAvailableDrivers(), true)) {
            throw new RuntimeException("PDO_DBLIB driver missing");
          }
          echo phpversion("pdo_dblib");
        '
      '';
      expected = package.version;
    };
    # A registered driver must reach FreeTDS and report its connection error.
    # This smoke check uses a reserved, non-listening loopback port.
    roundtrip = {
      script = ''
        ${runtime}/bin/php -r '
          $socket = stream_socket_server("tcp://127.0.0.1:0", $errno, $message, STREAM_SERVER_BIND);
          if ($socket === false) {
            throw new RuntimeException("Cannot reserve loopback test port: $message", $errno);
          }
          $address = stream_socket_get_name($socket, false);
          try {
            new PDO("dblib:host=$address;dbname=fixture", "fixture", "fixture", [PDO::ATTR_TIMEOUT => 2]);
          } catch (PDOException $error) {
            // SYBECONN is the FreeTDS DB-Library error for a refused socket.
            if ($error->getCode() !== 20009) {
              throw $error;
            }
            echo "dblib-connection-refused";
            exit(0);
          }
          throw new RuntimeException("A non-listening local socket unexpectedly accepted a connection");
        '
      '';
      expected = "dblib-connection-refused";
    };
  };
}

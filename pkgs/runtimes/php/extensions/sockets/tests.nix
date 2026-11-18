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
  };
in
context.mkSuite {
  inherit package;
  tools = [ runtime ];
  tests = {
    load = {
      script = ''${runtime}/bin/php -r 'echo phpversion("sockets");' '';
      expected = package.version;
    };
    roundtrip = {
      script = ''
        ${runtime}/bin/php -r '
          if (!socket_create_pair(AF_UNIX, SOCK_DGRAM, 0, $sockets)) {
            throw new RuntimeException("Could not create the Unix socket pair");
          }
          [$sender, $receiver] = $sockets;
          $payload = "TVP\0sockets";
          if (socket_send($sender, $payload, strlen($payload), 0) !== strlen($payload)
              || socket_recv($receiver, $received, 64, MSG_DONTWAIT) !== strlen($payload)
              || $received !== $payload) {
            throw new RuntimeException("Unix socket pair did not preserve the datagram");
          }
          echo bin2hex($received);
        '
      '';
      expected = "54565000736f636b657473";
    };
  };
}

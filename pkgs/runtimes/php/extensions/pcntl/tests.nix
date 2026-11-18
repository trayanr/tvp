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
      script = ''${runtime}/bin/php -r 'echo phpversion("pcntl");' '';
      expected = package.version;
    };
    roundtrip = {
      script = ''
        ${runtime}/bin/php -r '
          $pid = pcntl_fork();
          if ($pid === -1) {
            throw new RuntimeException(pcntl_strerror(pcntl_get_last_error()));
          }
          if ($pid === 0) {
            exit(37);
          }
          if (pcntl_waitpid($pid, $status) !== $pid || !pcntl_wifexited($status)) {
            throw new RuntimeException("pcntl_waitpid did not collect the child exit status");
          }
          echo pcntl_wexitstatus($status);
        '
      '';
      expected = "37";
    };
  };
}

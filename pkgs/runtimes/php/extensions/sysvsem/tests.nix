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
      script = ''${runtime}/bin/php -r 'echo phpversion("sysvsem");' '';
      expected = package.version;
    };
    roundtrip = {
      script = ''
        ${runtime}/bin/php -r '
          // Key zero is IPC_PRIVATE and creates a semaphore for this test.
          $semaphore = sem_get(0, 1, 0600);
          if ($semaphore === false) {
            throw new RuntimeException("Could not create a private semaphore");
          }
          try {
            if (!sem_acquire($semaphore, true) || sem_acquire($semaphore, true)) {
              throw new RuntimeException("Semaphore did not enforce a single acquisition");
            }
            if (!sem_release($semaphore) || !sem_acquire($semaphore, true)) {
              throw new RuntimeException("Semaphore was unavailable after release");
            }
          } finally {
            if (!sem_remove($semaphore)) {
              throw new RuntimeException("Could not remove the test semaphore");
            }
          }
          echo "semaphore released and reacquired";
        '
      '';
      expected = "semaphore released and reacquired";
    };
  };
}

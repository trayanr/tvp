{ ownedCLI, python3 }:
ownedCLI.python {
  name = "tvp-test-runner";
  command = "tvp-test";
  inherit python3;
  files = {
    "runner.py" = ./runner.py;
    "progress.py" = ./progress.py;
    "attempts.py" = ./attempts.py;
  };
  entrypoint = "runner.py";
  systemVariable = "TVP_TEST_SYSTEM";
}

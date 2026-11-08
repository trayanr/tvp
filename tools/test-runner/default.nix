{ ownedCLI, python3 }:
ownedCLI.python {
  name = "tvp-test-runner";
  command = "tvp-test";
  inherit python3;
  files = {
    "runner.py" = ./runner.py;
    "latest.py" = ./latest.py;
    "latest_worker.py" = ./latest_worker.py;
    "latest_graph.py" = ./latest_graph.py;
    "latest_supervisor.py" = ./latest_supervisor.py;
    "latest-plan.nix" = ./latest-plan.nix;
    "native_graph.py" = ../dependencies/recursive.py;
    "progress.py" = ./progress.py;
    "attempts.py" = ./attempts.py;
    "verifier.py" = ./verifier.py;
    "representative.py" = ./representative.py;
    "graph_compare.py" = ../graph/compare.py;
  };
  entrypoint = "runner.py";
  systemVariable = "TVP_TEST_SYSTEM";
}

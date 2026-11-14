{ runCommand, python3 }:
runCommand "tvp-test-runner-tests" { nativeBuildInputs = [ python3 ]; } ''
  set -e -o pipefail
  cp ${../latest.py} latest.py
  cp ${../latest_worker.py} latest_worker.py
  cp ${../latest_graph.py} latest_graph.py
  cp ${../latest_supervisor.py} latest_supervisor.py
  cp ${../latest-plan.nix} latest-plan.nix
  cp ${../../dependencies/recursive.py} native_graph.py
  cp ${./test_latest.py} test_latest.py
  cp ${../runner.py} runner.py
  cp ${../progress.py} progress.py
  cp ${../attempts.py} attempts.py
  cp ${../verifier.py} verifier.py
  cp ${../representative.py} representative.py
  cp ${../batch_report.py} batch_report.py
  cp ${./test_batch_report.py} test_batch_report.py
  cp ${../../graph/compare.py} graph_compare.py
  cp ${./test_verifier.py} test_verifier.py
  cp ${./test_runner.py} test_runner.py
  cp ${./test_representative.py} test_representative.py
  # Keep diagnostics and elapsed time in the build log, outside the receipt.
  python3 -m unittest -v test_runner test_verifier test_representative test_latest test_batch_report
  printf 'test-runner tests passed\n' > "$out"
''

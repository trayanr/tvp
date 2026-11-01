{ runCommand, python3 }:
runCommand "tvp-test-runner-tests" { nativeBuildInputs = [ python3 ]; } ''
  set -e -o pipefail
  cp ${../runner.py} runner.py
  cp ${../progress.py} progress.py
  cp ${../attempts.py} attempts.py
  cp ${./test_runner.py} test_runner.py
  # Keep diagnostics and elapsed time in the build log, outside the receipt.
  python3 -m unittest -v test_runner
  printf 'test-runner tests passed\n' > "$out"
''

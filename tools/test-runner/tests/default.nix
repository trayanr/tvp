{ runCommand, python3 }:
runCommand "tvp-test-runner-tests" { nativeBuildInputs = [ python3 ]; } ''
  set -o pipefail
  cp ${../runner.py} runner.py
  cp ${../progress.py} progress.py
  cp ${../attempts.py} attempts.py
  cp ${./test_runner.py} test_runner.py
  python3 -m unittest -v test_runner 2>&1 | tee "$out"
''

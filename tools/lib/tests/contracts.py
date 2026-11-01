import json
import os
import signal
import subprocess
import sys

shell, python, prefix, system = sys.argv[1:]
# A caller path and values containing shell metacharacters must remain data.
caller = "/caller with spaces:/quote'and$dollar:/last"
args = ["a b", "", "'quoted'", '"double"', "$HOME;exit 91", "*", "line\nbreak"]
env = dict(os.environ, PATH=caller, TVP_TEST_SYSTEM="caller-value",
           TVP_PROBE_VALUE="value with 'quotes' $dollars\nand newline")
env.pop("TVP_INTENTIONALLY_UNSET", None)
r = subprocess.run([shell, *args], env=env, capture_output=True, text=True, check=True)
assert r.stdout == prefix + ":" + caller + "\n" + "".join("<" + a + ">\n" for a in args)
for mode in ["pipe", "unset", "fail"]:
    r = subprocess.run([shell, mode], env=env, capture_output=True, text=True)
    assert r.returncode != 0 and "unreachable" not in r.stdout, (mode, r)
r = subprocess.run([python, *args], env=env, capture_output=True, text=True, check=True)
data = json.loads(r.stdout)
assert data == dict(args=args, path=caller, system=system, value=env["TVP_PROBE_VALUE"])
assert subprocess.run([python, "exit", "37"], env=env).returncode == 37
with subprocess.Popen([python, "signal"], env=env, stdout=subprocess.PIPE, text=True) as p:
    try:
        # The entrypoint must replace the wrapper, so signals reach this PID.
        assert int(p.stdout.readline()) == p.pid
        p.send_signal(signal.SIGTERM)
        assert p.wait(timeout=10) == -signal.SIGTERM
    finally:
        if p.poll() is None:
            p.kill()
            p.wait()

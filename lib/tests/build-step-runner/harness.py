"""Test harness only. Runner runtime is owned Bash/base/tools."""
import base64
import json
import os
import re
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time

runtime, bash = sys.argv[1:]


def events(data):
    return [json.loads(line[len(b"@tvp-step "):]) for line in data.splitlines()
            if line.startswith(b"@tvp-step ")]


def check_events(data, terminal, count=None):
    rows = events(data)
    starts = [r for r in rows if r["event"] == "start"]
    ends = [r for r in rows if r["event"] != "start"]
    assert len(starts) == len(ends) and starts, rows
    assert [r["name"] for r in starts] == [r["name"] for r in ends], rows
    assert ends[-1]["event"] == terminal, rows
    if count is not None:
        assert len(starts) == count, rows
    return rows


def record(name, result, protocol=b"", **extra):
    print(json.dumps(dict(case=name, returnCode=result.returncode,
                          stdout=base64.b64encode(result.stdout).decode(),
                          stderr=base64.b64encode(result.stderr).decode(),
                          protocol=base64.b64encode(protocol).decode(), **extra)), flush=True)


def run(name, expected=0, fd="absent"):
    with tempfile.TemporaryDirectory(prefix="step fixture ") as directory, tempfile.TemporaryDirectory(prefix="step-output-") as output:
        env = dict(os.environ, out=output)
        env.pop("NIX_LOG_FD", None)
        with tempfile.TemporaryFile() as log:
            pass_fds = ()
            if fd == "valid":
                env["NIX_LOG_FD"] = str(log.fileno())
                pass_fds = (log.fileno(),)
            elif fd != "absent":
                env["NIX_LOG_FD"] = fd
            result = subprocess.run([bash, runtime + "/" + name, directory], env=env,
                                    capture_output=True, pass_fds=pass_fds, timeout=20,
                                    start_new_session=True)
            log.seek(0)
            protocol = log.read()
        record(name + ":" + fd, result, protocol)
        assert result.returncode == expected, result
        rows = check_events(result.stderr, "completion" if expected == 0 else "failure")
        if expected:
            assert not Path(directory, "forbidden").exists()
            assert b"unreachable" not in result.stdout
            assert rows[-1]["status"] == expected
        if fd == "valid":
            phases = [json.loads(line[len(b"@nix "):]) for line in protocol.splitlines()]
            assert phases == [dict(action="setPhase", phase=r["name"])
                              for r in rows if r["event"] == "start"], phases
        else:
            assert protocol == b""
        if name == "streams":
            assert result.stdout == b" a ' \" $() ;\nlast\n", result.stdout
            ordinary = re.sub(rb'\n@tvp-step [^\n]*\n', b"", result.stderr)
            assert ordinary == b"err  \nsecond", ordinary
        if name == "success":
            assert Path(directory, "order").read_bytes() == b"first\nsecond\ninserted\nreplaced\n"
            assert len(rows) == 10 and not any("disabled" in r["name"] for r in rows)
        assert not Path(directory, "forbidden-quote").exists()
        assert not Path(directory, "env-vars").exists()
        if name == "compiler":
            assert subprocess.check_output([str(Path(directory, "smoke"))]).strip()


def live_group(group):
    # Linux native fixture. Zombies cannot run; collect their separate evidence.
    running, zombies = [], []
    for entry in Path("/proc").iterdir():
        if not entry.name.isdigit():
            continue
        try:
            data = (entry / "stat").read_text().rsplit(")", 1)[1].split()
            if int(data[2]) == group:
                (zombies if data[0] == "Z" else running).append(int(entry.name))
        except (FileNotFoundError, ProcessLookupError):
            pass
    return running, zombies


def cancel(sig):
    with tempfile.TemporaryDirectory(prefix="step cancellation ") as directory:
        child = subprocess.Popen([bash, runtime + "/cancel", directory],
                                 stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                 start_new_session=True)
        owned = None
        pids = []
        try:
            deadline = time.monotonic() + 10
            while not Path(directory, "ready").exists():
                assert child.poll() is None, "runner exited before handshake"
                assert time.monotonic() < deadline, "no active handshake"
                time.sleep(0.01)
            pids = [int(Path(directory, n + ".pid").read_text())
                    for n in ["leader", "nested", "leaf"]]
            owned = os.getpgid(pids[0])
            assert owned == pids[0] and owned != os.getpgrp()
            assert all(os.getpgid(pid) == owned for pid in pids)
            assert all(pid in live_group(owned)[0] for pid in pids)
            os.kill(child.pid, sig)
            out, err = child.communicate(timeout=8)
            result = subprocess.CompletedProcess(child.args, child.returncode, out, err)
            rows = check_events(err, "cancellation", 1)
            assert child.returncode == -sig, (child.returncode, err)
            deadline = time.monotonic() + 3
            while live_group(owned)[0] and time.monotonic() < deadline:
                time.sleep(0.01)
            running, zombies = live_group(owned)
            record(signal.Signals(sig).name, result, pids=pids, group=owned,
                   survivingRunning=running, zombies=zombies, events=rows)
            assert not running and not zombies, (running, zombies)
            assert not Path(directory, "forbidden").exists()
        finally:
            if owned:
                try:
                    os.killpg(owned, signal.SIGKILL)
                except ProcessLookupError:
                    pass
            if child.poll() is None:
                child.kill()
            child.communicate(timeout=5)


def broken_logging():
    with tempfile.TemporaryDirectory() as directory:
        reader, writer = os.pipe()
        os.close(reader)
        try:
            env = dict(os.environ, NIX_LOG_FD=str(writer))
            result = subprocess.run([bash, runtime + "/exit7", directory], env=env,
                                    pass_fds=(writer,), capture_output=True, timeout=10,
                                    start_new_session=True)
            assert result.returncode == 7
            check_events(result.stderr, "failure", 1)
            record("broken-log-pipe", result)
        finally:
            os.close(writer)
        with open("/dev/full", "wb") as full:
            result = subprocess.run([bash, runtime + "/exit7", directory],
                                    stdout=subprocess.PIPE, stderr=full, timeout=10,
                                    start_new_session=True)
            assert result.returncode == 7
            print(json.dumps(dict(case="terminal-log-write-failure", returnCode=7)), flush=True)


run("success")
for fd in ["absent", "valid", "999999", "invalid"]:
    run("streams", fd=fd)
    run("exit7", 7, fd=fd)
for case in ["false", "pipeline", "substitution", "function", "source"]:
    run(case, 1)
run("exit143", 143)
run("signal143", 143)
run("missing", 72)
for case in ["handled", "scopes", "lists", "literalCwd", "compiler"]:
    run(case)
broken_logging()
for sig in [signal.SIGTERM, signal.SIGINT, signal.SIGHUP]:
    cancel(sig)
print("Runner fixture contracts passed.", flush=True)

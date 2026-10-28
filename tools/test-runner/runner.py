"""Run one frozen Nix suite and report realised results independently of log format."""

import argparse
import collections
import fcntl
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import threading
import time

from progress import members, observe, root_path, valid_paths
from attempts import combine, register_retry


TERMINAL = {"passed", "failed", "cancelled", "error", "interrupted"}
ANSI = re.compile(r"\x1b\[[0-9;]*m")


def write_json(path, value):
    temporary = path.with_suffix(".tmp")
    temporary.write_text(json.dumps(value, indent=2) + "\n")
    os.replace(temporary, path)


def lease_held(path):
    with path.open("a") as lease:
        try:
            fcntl.flock(lease, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return True
        return False


def apply_event(active, event, log):
    """Activity events improve live detail; store validity decides pass/fail."""
    if not isinstance(event, dict):
        return
    action = event.get("action")
    identifier = str(event.get("id"))
    fields = event.get("fields") or []
    if not isinstance(fields, list):
        fields = []
    if action == "start" and event.get("type") in (105, 108) and fields and isinstance(fields[0], str):
        drv = fields[0]
        phase = "building" if event["type"] == 105 else "fetching"
        active[identifier] = {"drv": drv, "startedAt": time.time(), "phase": phase}
        log.write(phase + " " + str(drv) + "\n")
    elif action == "stop":
        active.pop(identifier, None)
    elif action == "result" and event.get("type") == 104 and identifier in active and fields:
        active[identifier]["phase"] = str(fields[0])
    elif action == "msg":
        log.write(ANSI.sub("", str(event.get("msg", ""))) + "\n")


def useful_event(event, active):
    # internal-json includes debug HTTP traffic even at normal verbosity.
    # Keep build/fetch lifecycles, phases and user-facing messages, not that
    # unbounded traffic. Full compiler logs remain available through nix log.
    if not isinstance(event, dict):
        return False
    action = event.get("action")
    if action == "msg":
        return event.get("level", 0) in range(4)
    if action == "start":
        return event.get("type") in (105, 108)
    return str(event.get("id")) in active and (
        action == "stop" or action == "result" and event.get("type") == 104
    )


def work(run, global_fd, lease_fd):
    plan = json.loads((run / "plan.json").read_text())
    state = json.loads((run / "state.json").read_text())
    state.update(phase="running", pid=os.getpid(), buildStartedAt=time.time(), active={})
    write_json(run / "state.json", state)
    stopped = threading.Event()
    child = None
    active = {}
    lock = threading.Lock()

    def stop(_signum, _frame):
        stopped.set()
        if child is not None and child.poll() is None:
            try:
                os.killpg(child.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    targets = [plan["aggregate"]] if state["full"] else [job["drv"] for job in plan["jobs"]]
    command = ["nix", "build", "--keep-going", "--log-format", "internal-json",
               "--out-link", str(run / "result")]
    if state.get("maxJobs") is not None:
        command += ["--max-jobs", str(state["maxJobs"])]
    if state.get("cores") is not None:
        command += ["--cores", str(state["cores"])]
    command += [drv + "^*" for drv in targets]
    write_json(run / "command.json", command)
    try:
        with (run / "nix.log").open("w", buffering=1) as log, (run / "events.jsonl").open("w") as events:
            child = subprocess.Popen(command, stdout=log, stderr=subprocess.PIPE,
                                     text=True, errors="replace", start_new_session=True)
            if stopped.is_set():
                stop(None, None)

            def read_events():
                for line in child.stderr:
                    if line.startswith("@nix "):
                        try:
                            event = json.loads(line[5:])
                        except json.JSONDecodeError:
                            log.write(line)
                            continue
                        with lock:
                            if useful_event(event, active):
                                events.write(line)
                                apply_event(active, event, log)
                    else:
                        events.write(line)
                        log.write(line)
                events.flush()

            reader = threading.Thread(target=read_events, daemon=True)
            reader.start()
            while True:
                try:
                    observe(plan, state, run)
                    state.pop("monitorError", None)
                except (OSError, RuntimeError, subprocess.SubprocessError) as error:
                    # Progress queries must not cancel a valid long-running build.
                    state["monitorError"] = str(error)
                with lock:
                    state["active"] = dict(active)
                write_json(run / "state.json", state)
                if child.poll() is not None:
                    break
                stopped.wait(5)
                if stopped.is_set():
                    try:
                        child.wait(timeout=30)
                    except subprocess.TimeoutExpired:
                        os.killpg(child.pid, signal.SIGKILL)
            code = child.wait()
            reader.join()
        state["cancelled"] = stopped.is_set()
        observe(plan, state, run, final=True)
        all_passed = all(job["status"] == "passed" for job in state["jobs"].values())
        state.update(phase="cancelled" if stopped.is_set() else "passed" if code == 0 and all_passed else "failed",
                     returnCode=code, finishedAt=time.time(), active={})
    except Exception as error:
        if child is not None and child.poll() is None:
            stop(None, None)
            child.wait()
        state.update(phase="error", error=str(error), finishedAt=time.time(), active={})
        print(str(error), file=sys.stderr)
    finally:
        write_json(run / "state.json", state)
        os.close(global_fd)
        os.close(lease_fd)
    return 0 if state["phase"] == "passed" else 1


def start(args):
    if args.retry_of:
        args.retry_of = args.retry_of.resolve()
    directory = args.state_dir.resolve()
    directory.mkdir(parents=True, exist_ok=True)
    with (directory / "lock").open("a") as global_lease:
        try:
            fcntl.flock(global_lease, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise RuntimeError("A suite is already running here; use 'status'.") from None
        run = directory / "runs" / (time.strftime("%Y%m%dT%H%M%SZ", time.gmtime()) + f"-{os.getpid()}")
        (run / "roots").mkdir(parents=True)
        with (run / "worker.lock").open("a") as lease:
            fcntl.flock(lease, fcntl.LOCK_EX)
            state = {"phase": "preparing", "startedAt": time.time(), "maxJobs": args.jobs,
                     "cores": args.cores, "jobs": {}, "full": not bool(args.only)}
            write_json(run / "state.json", state)
            temporary = directory / f"latest-{os.getpid()}.tmp"
            temporary.symlink_to(run)
            os.replace(temporary, directory / "latest")
            try:
                # Keep the executable and its interpreter alive after nix run exits.
                root_path(run / "runner", Path(__file__).resolve().parents[2])
                command = ["nix", "build", "--no-write-lock-file", "--out-link", str(run / "plan"),
                           args.flake + "#testPlans." + args.system]
                with (run / "prepare.log").open("w") as log:
                    subprocess.run(command, check=True, stdout=log, stderr=subprocess.STDOUT)
                plan = json.loads((run / "plan").read_text())
                if plan.get("schema") != 1:
                    raise RuntimeError("Unsupported test plan schema")
                names = {job["name"] for job in plan["jobs"]}
                unknown = set(args.only or []) - names
                if unknown:
                    raise RuntimeError("Unknown suites: " + ", ".join(sorted(unknown)))
                if args.only:
                    plan["jobs"] = [job for job in plan["jobs"] if job["name"] in args.only]
                if not plan["jobs"] or any(not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._+-]*", job["name"]) for job in plan["jobs"]):
                    raise RuntimeError("Empty plan or invalid suite name")
                write_json(run / "plan.json", plan)
                jobs = members(plan, run)
                present = valid_paths(p for job in jobs for test in (job.get("tests") or [job]) for p in test["outputs"])
                state["jobs"] = {job["name"]: {"status": "pending", "cachedAtStart": all(p in present for test in (job.get("tests") or [job]) for p in test["outputs"])} for job in jobs}
                state["phase"] = "starting"
                write_json(run / "state.json", state)
                if args.retry_of:
                    register_retry(args.retry_of, run)
                with (run / "worker.log").open("w") as log:
                    subprocess.Popen([sys.executable, __file__, "_work", str(run),
                                      str(global_lease.fileno()), str(lease.fileno())],
                                     stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT,
                                     start_new_session=True, pass_fds=(global_lease.fileno(), lease.fileno()))
            except Exception as error:
                state.update(phase="error", error=str(error), finishedAt=time.time())
                write_json(run / "state.json", state)
                raise
    print("Started:", run)
    print(f"Suites: {len(plan['jobs'])}; cached at start: {sum(x['cachedAtStart'] for x in state['jobs'].values())}; declared broken: {len(plan['skipped'])}")
    print("Progress: nix run .#test -- status --run", args.retry_of.resolve() if args.retry_of else run)
    print("Frozen runner:", run / "runner/bin/tvp-test", "status --run", run)
    return 0


def status(run, as_json=False, attempt_only=False):
    state = json.loads((run / "state.json").read_text())
    if state["phase"] not in TERMINAL and not lease_held(run / "worker.lock"):
        state["phase"] = "interrupted"
    now = state.get("finishedAt", time.time())
    state["elapsedSeconds"] = round(now - state["startedAt"])
    counts = collections.Counter(job["status"] for job in state["jobs"].values())
    state["counts"] = dict(counts)
    state["run"] = str(run)
    plan = json.loads((run / "plan.json").read_text()) if (run / "plan.json").exists() else {}
    if plan and state["phase"] not in {"preparing", "starting", "error"}:
        try:
            observe(plan, state, run, final=state["phase"] in TERMINAL, root_completed=False)
            state.pop("monitorError", None)
        except (OSError, RuntimeError, subprocess.SubprocessError, ValueError) as error:
            state["monitorError"] = str(error)
    counts = collections.Counter(job["status"] for job in state["jobs"].values())
    state["counts"] = dict(counts)
    state["source"] = plan.get("source")
    state["declaredBroken"] = plan.get("skipped", [])
    if not attempt_only:
        state = combine(run, state, lambda path: status(path, as_json=None, attempt_only=True))
        counts = collections.Counter(state["counts"])
    if as_json is None:
        return state
    if as_json:
        print(json.dumps(state, indent=2))
        return state
    duration = state["elapsedSeconds"]
    print(f"{state['phase']} | {duration // 3600:02}:{duration // 60 % 60:02}:{duration % 60:02} elapsed")
    print(f"Suites: {counts['passed']}/{len(state['jobs'])} passed; {counts['failed-or-blocked']} failed/blocked; {counts['pending']} pending; {counts['cancelled']} cancelled")
    if state.get("testCounts"):
        tests = state["testCounts"]
        print(f"Tests/checks: {tests['passed']}/{sum(tests.values())} passed; {tests['failed-or-blocked']} failed/blocked; {tests['pending']} pending; {tests['cancelled']} cancelled")
    if state.get("retrySuites"):
        print(f"Latest retry results: {state['retrySuites']} suites across {len(state['attempts']) - 1} linked attempt(s).")
    print(f"Cached at start: {sum(x['cachedAtStart'] for x in state['jobs'].values())}; declared broken: {len(plan.get('skipped', []))}")
    if plan.get("source"):
        print("Snapshot:", plan.get("revision") or "uncommitted", Path(plan["source"]).name)
    for activity in state.get("active", {}).values():
        name = Path(activity["drv"]).name[33:].removesuffix(".drv")
        print(f"  {name}: {activity['phase']} ({int(time.time() - activity['startedAt'])}s)")
    if state["phase"] == "running" and not state.get("active"):
        print("Nix is resolving dependencies, checking caches or starting builds.")
    failed = [name for name, job in state["jobs"].items() if job["status"] == "failed-or-blocked"]
    for name in failed[:10]:
        print("  failed/blocked:", name)
    if len(failed) > 10:
        print("  Use --json for the remaining failures.")
    if state.get("error"):
        print(state["error"])
    if state.get("monitorError"):
        print("Progress query:", state["monitorError"])
    for error in state.get("retryErrors", []):
        print("Retry error:", error["error"], "(" + error["run"] + ")")
    print("Logs:", run / "nix.log")
    return state


def positive(value):
    number = int(value)
    if number < 1:
        raise argparse.ArgumentTypeError("must be positive")
    return number


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "_work":
        return work(Path(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4]))
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    launch = commands.add_parser("start", help="freeze and launch the full suite in the background")
    launch.add_argument("--flake", default=".")
    launch.add_argument("--system", default=os.environ.get("TVP_TEST_SYSTEM", "x86_64-linux"))
    launch.add_argument("--state-dir", type=Path, default=Path(".tvp-tests"))
    launch.add_argument("--jobs", type=positive, help="override Nix's max-jobs setting")
    launch.add_argument("--cores", type=int, help="override Nix's cores setting (0 uses all cores)")
    launch.add_argument("--only", action="append", help="run only this exact suite name (repeatable)")
    launch.add_argument("--retry-of", type=Path, help="link this run's results to an earlier run")
    for name in ("status", "wait", "stop"):
        command = commands.add_parser(name)
        command.add_argument("--state-dir", type=Path, default=Path(".tvp-tests"))
        command.add_argument("--run", type=Path)
        if name == "status":
            command.add_argument("--json", action="store_true")
            command.add_argument("--attempt-only", action="store_true", help="show this frozen attempt without linked retries")
    args = parser.parse_args()
    try:
        if args.command == "start":
            return start(args)
        run = (args.run or args.state_dir / "latest").resolve()
        if args.command == "stop":
            state = json.loads((run / "state.json").read_text())
            if not lease_held(run / "worker.lock") or not state.get("pid"):
                raise RuntimeError("This run has no active worker")
            os.kill(state["pid"], signal.SIGTERM)
            print("Stopping:", run)
            return 0
        while True:
            state = status(run, getattr(args, "json", False), getattr(args, "attempt_only", False))
            if args.command != "wait":
                return 0
            if state["phase"] in TERMINAL:
                return 0 if state["phase"] == "passed" else 1
            time.sleep(10)
    except (OSError, RuntimeError, ValueError, subprocess.SubprocessError) as error:
        print(str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())

"""Run one frozen Nix suite and report realised results independently of log format."""

import argparse
import collections
from datetime import datetime, timezone
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

from progress import members, observe, observed_paths, production_stages, root_path, stage_counts, valid_paths
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
        # Nix actBuild gives the machine URI as its second field. A local
        # builder sends an empty string. actSubstitute describes cache work.
        machine = fields[1] if len(fields) > 1 and isinstance(fields[1], str) else ""
        location = "cache" if phase == "fetching" else builder_location(machine)
        active[identifier] = {"drv": drv, "startedAt": time.time(), "phase": phase, "location": location}
        suffix = " on " + location if location.startswith("remote ") else ""
        log.write(phase + " " + drv + suffix + "\n")
        return active[identifier]
    elif action == "stop":
        active.pop(identifier, None)
    elif action == "result" and event.get("type") == 104 and identifier in active and fields:
        active[identifier]["phase"] = str(fields[0])
    elif action == "result" and event.get("type") == 101 and identifier in active and fields and isinstance(fields[0], str):
        # Nix's resBuildLogLine carries both builder stdout and stderr. Prefix
        # concurrent output without making it part of the progress/state data.
        source = Path(active[identifier]["drv"]).name
        log.write(source + "> " + ANSI.sub("", fields[0]) + "\n")
    elif action == "msg":
        log.write(ANSI.sub("", str(event.get("msg", ""))) + "\n")


def builder_location(machine):
    if not machine:
        return "local"
    # Show the endpoint without the login, query options, or SSH key path.
    authority = machine.split("://", 1)[-1].split("/", 1)[0].split("?", 1)[0]
    host = re.sub(r"[^a-zA-Z0-9_.:\[\]-]", "", authority.rsplit("@", 1)[-1])[:64]
    return "remote " + host if host else "remote builder"


def note_activity(item, builds, downloads):
    """Prefer the outer remote dispatch over the remote daemon's local echo."""
    location = item.get("location", "cache" if item["phase"] == "fetching" else "local")
    drv = item["drv"]
    if location == "cache":
        downloads.add(drv)
    elif drv not in builds or location != "local":
        builds[drv] = location


def useful_event(event, active):
    # internal-json includes debug HTTP traffic even at normal verbosity.
    # Keep build/fetch lifecycles, phases, compiler output and user-facing
    # messages, without persisting unbounded HTTP/query/debug traffic.
    if not isinstance(event, dict):
        return False
    action = event.get("action")
    if action == "msg":
        return event.get("level", 0) in range(4)
    if action == "start":
        return event.get("type") in (105, 108)
    return str(event.get("id")) in active and (
        action == "stop" or action == "result" and event.get("type") in (101, 104)
    )


def build_targets(plan, full):
    targets = [plan["aggregate"]] if full else [job["drv"] for job in plan["jobs"]]
    # A cached suite retains only the output selected by each installed link.
    # Request siblings explicitly, including multioutput tests in partial suites.
    targets += [item["drv"] for job in plan["jobs"]
                for item in [job] + job.get("tests", []) if len(item["outputs"]) > 1]
    return list(dict.fromkeys(targets))


def work(run, global_fd, lease_fd):
    plan = json.loads((run / "plan.json").read_text())
    state = json.loads((run / "state.json").read_text())
    state.update(phase="running", pid=os.getpid(), buildStartedAt=time.time(), active={})
    stopped = threading.Event()
    wake = threading.Event()
    finished = threading.Event()
    owner_gone = threading.Event()
    child = None
    active = {}
    compact = os.environ.get("TVP_CI_PROGRESS") == "1"
    build_locations = {}
    downloads = set()
    lock = threading.Lock()
    protected = set()

    def checkpoint():
        with lock:
            state["active"] = dict(active)
            if compact:
                state["activityStarts"] = dict(collections.Counter(build_locations.values()))
                state["activityStarts"]["cache"] = len(downloads)
        write_json(run / "state.json", state)

    def rooting(completed, total):
        state.update(operation="registering-roots", rooting={"completed": completed, "total": total})
        checkpoint()

    def stop(_signum, _frame):
        stopped.set()
        wake.set()
        if child is not None and child.poll() is None:
            try:
                os.killpg(child.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass

    def watch_owner():
        while not finished.wait(0.5):
            try:
                held = all(lease_held(Path(path)) for path in (
                    state["ownerLock"], state.get("parentOwnerLock")
                ) if path)
            except OSError:
                held = False
            if not held:
                owner_gone.set()
                stop(None, None)
                return

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    # A published PID is a promise that stop can produce a terminal receipt.
    # Install both handlers before allowing the CLI to signal this worker.
    write_json(run / "state.json", state)
    targets = build_targets(plan, state["full"])
    multioutput = any(len(item["outputs"]) > 1 for job in plan["jobs"]
                      for item in [job] + job.get("tests", []))
    # Nix names secondary links with output suffixes. Keep these additional
    # roots together; result remains the stable handle for the first target.
    out_link = run / "roots" / "build" if multioutput else run / "result"
    command = ["nix", "build", "--show-trace", "--keep-going", "--print-build-logs", "--log-format", "internal-json",
               "--out-link", str(out_link)]
    if state.get("maxJobs") is not None:
        command += ["--max-jobs", str(state["maxJobs"])]
    if state.get("cores") is not None:
        command += ["--cores", str(state["cores"])]
    command += [drv + "^*" for drv in targets]
    write_json(run / "command.json", command)
    try:
        stages = production_stages(members(plan, run))
        if state.get("ownerLock"):
            threading.Thread(target=watch_owner, daemon=True).start()
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
                                if event.get("action") in {"start", "stop"}:
                                    # Retain activity timings for future estimates.
                                    event["observedAt"] = time.time()
                                    events.write("@nix " + json.dumps(event) + "\n")
                                else:
                                    events.write(line)
                                started = apply_event(active, event, log)
                                if compact and started:
                                    note_activity(started, build_locations, downloads)
                    else:
                        events.write(line)
                        log.write(line)
                events.flush()
                wake.set()

            reader = threading.Thread(target=read_events, daemon=True)
            reader.start()
            while True:
                try:
                    with lock:
                        state["active"] = dict(active)
                    observe(plan, state, run, protected=protected, on_roots=rooting, stages=stages)
                    state.pop("monitorError", None)
                    state["operation"] = "building"
                except (OSError, RuntimeError, subprocess.SubprocessError) as error:
                    # Progress queries must not cancel a valid long-running build.
                    state["monitorError"] = str(error)
                checkpoint()
                if child.poll() is not None:
                    break
                wake.wait(5)
                wake.clear()
                if stopped.is_set():
                    try:
                        child.wait(timeout=30)
                    except subprocess.TimeoutExpired:
                        os.killpg(child.pid, signal.SIGKILL)
            code = child.wait()
            reader.join()
        if code == 0 and multioutput:
            root_path(run / "result", out_link.resolve(strict=True))
        state["cancelled"] = stopped.is_set()
        state["operation"] = "checking-outputs"
        checkpoint()
        observe(plan, state, run, final=True, protected=protected, on_roots=rooting, stages=stages)
        state.pop("monitorError", None)
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
        finished.set()
        if owner_gone.is_set():
            state["cancelReason"] = "Controlling process exited"
        write_json(run / "state.json", state)
        os.close(global_fd)
        os.close(lease_fd)
    return 0 if state["phase"] == "passed" else 1


def start(args, return_run=False):
    if args.owner_lock:
        args.owner_lock = args.owner_lock.resolve()
        if not lease_held(args.owner_lock):
            raise RuntimeError("The controlling process must hold --owner-lock before starting")
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
            scope = "full" if args.full else "smoke"
            state = {"phase": "preparing", "startedAt": time.time(), "maxJobs": args.jobs,
                     "cores": args.cores, "jobs": {}, "full": args.full and not bool(args.only),
                     "validationScope": scope}
            if args.owner_lock:
                state["ownerLock"] = str(args.owner_lock)
            if getattr(args, "parent_owner_lock", None):
                state["parentOwnerLock"] = str(args.parent_owner_lock)
            write_json(run / "state.json", state)
            temporary = directory / f"latest-{os.getpid()}.tmp"
            temporary.symlink_to(run)
            os.replace(temporary, directory / "latest")
            try:
                # Keep the executable and its interpreter alive after nix run exits.
                root_path(run / "runner", Path(__file__).resolve().parents[2])
                frozen_plan = getattr(args, "frozen_plan", None)
                with (run / "prepare.log").open("w") as log:
                    if frozen_plan is None:
                        plan_attribute = "testPlans" if args.full else "smokeTestPlans"
                        command = ["nix", "build", "--show-trace", "--no-write-lock-file", "--out-link", str(run / "plan"),
                                   args.flake + "#" + plan_attribute + "." + args.system]
                        subprocess.run(command, check=True, stdout=log, stderr=subprocess.STDOUT)
                    else:
                        root_path(run / "plan", frozen_plan)
                        print(f"Reused CI smoke plan {frozen_plan}", file=log)
                plan = json.loads((run / "plan").read_text())
                if plan.get("schema") != 1:
                    raise RuntimeError("Unsupported test plan schema")
                if frozen_plan is not None and plan.get("system") != args.system:
                    raise RuntimeError("Frozen CI smoke plan has a different system")
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
                stages = production_stages(jobs)
                present = valid_paths(observed_paths(jobs, stages))
                if stages:
                    state["stageCounts"] = stage_counts(stages, present, state)
                    for counts in state["stageCounts"].values():
                        counts["cachedAtStart"] = counts["ready"]
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
    if return_run:
        return run
    if getattr(args, "json", False):
        print(json.dumps({"run": str(run), "runner": str(run / "runner/bin/tvp-test"),
                          "suites": len(plan["jobs"]), "source": plan["source"],
                          "validationScope": scope, "full": state["full"],
                          "cachedAtStart": sum(x["cachedAtStart"] for x in state["jobs"].values()),
                          "declaredBroken": len(plan["skipped"])}))
    else:
        print("Started:", run)
        print(f"Suites: {len(plan['jobs'])}; cached at start: {sum(x['cachedAtStart'] for x in state['jobs'].values())}; declared broken: {len(plan['skipped'])}")
        print("Progress: nix run .#test -- status --run", args.retry_of.resolve() if args.retry_of else run)
        print("Frozen runner:", run / "runner/bin/tvp-test", "status --run", run)
    return 0


def run_all(args):
    directory = args.state_dir.resolve()
    directory.mkdir(parents=True, exist_ok=True)
    owner_path = directory / f"all-owner-{os.getpid()}.lock"
    parent_owner = args.owner_lock.resolve() if args.owner_lock else None
    if parent_owner and not lease_held(parent_owner):
        raise RuntimeError("The controlling process must hold --owner-lock before starting")
    frozen_plan = os.environ.get("TVP_CI_FROZEN_SMOKE_PLAN")
    if frozen_plan and (not parent_owner or args.full or not Path(frozen_plan).is_absolute()):
        raise RuntimeError("A frozen CI smoke plan requires an absolute path, smoke scope and a controlling process")
    # Reuse the existing worker. Releasing this lock also stops it if the
    # foreground command is killed before it can return a result.
    with owner_path.open("a") as owner:
        fcntl.flock(owner, fcntl.LOCK_EX | fcntl.LOCK_NB)
        launch = argparse.Namespace(**vars(args), parent_owner_lock=parent_owner)
        launch.owner_lock = owner_path
        launch.frozen_plan = Path(frozen_plan) if frozen_plan else None
        compact = os.environ.get("TVP_CI_PROGRESS") == "1" and not args.json
        preparing = time.monotonic()
        if compact:
            print_ci("Smoke preparation started")
        try:
            run = start(launch, return_run=True)
        except (OSError, RuntimeError, ValueError, subprocess.SubprocessError):
            if compact:
                print_ci(f"Smoke preparation failed after {time.monotonic() - preparing:.1f}s")
            raise
        if compact:
            print_ci(f"Smoke preparation finished in {time.monotonic() - preparing:.1f}s")
        interrupted = None

        def stop(signum, _frame):
            nonlocal interrupted
            interrupted = signum
            # The worker may still be starting. Its owner watcher will stop it
            # when this lease closes, without racing PID publication.
            fcntl.flock(owner, fcntl.LOCK_UN)

        previous = {sig: signal.signal(sig, stop) for sig in (signal.SIGTERM, signal.SIGINT)}
        try:
            code = wait(run, quiet=args.json, compact=compact)
        finally:
            for sig, handler in previous.items():
                signal.signal(sig, handler)
        result = status(run, as_json=None, inspect_store=False)
        result["runner"] = str(run / "runner/bin/tvp-test")
        write_json(run / "result.json", result)
        if args.json:
            print(json.dumps(result))
        return 128 + interrupted if interrupted else code


def status(run, as_json=False, attempt_only=False, inspect_store=True, plan=None):
    state = json.loads((run / "state.json").read_text())
    if state["phase"] not in TERMINAL and not lease_held(run / "worker.lock"):
        state["phase"] = "interrupted"
    now = state.get("finishedAt", time.time())
    state["elapsedSeconds"] = round(now - state["startedAt"])
    counts = collections.Counter(job["status"] for job in state["jobs"].values())
    state["counts"] = dict(counts)
    state["run"] = str(run)
    if plan is None:
        path = run / "plan.json"
        plan = json.loads(path.read_text()) if path.exists() else {}
    if inspect_store and plan and state["phase"] not in {"preparing", "starting", "error"}:
        try:
            observe(plan, state, run, final=state["phase"] in TERMINAL, root_completed=False)
            state.pop("monitorError", None)
        except (OSError, RuntimeError, subprocess.SubprocessError, ValueError) as error:
            state["monitorError"] = str(error)
    counts = collections.Counter(job["status"] for job in state["jobs"].values())
    state["counts"] = dict(counts)
    state["source"] = plan.get("source")
    state["revision"] = plan.get("revision")
    state["declaredBroken"] = plan.get("skipped", [])
    if not attempt_only:
        state = combine(run, state, lambda path: status(
            path, as_json=None, attempt_only=True, inspect_store=inspect_store))
        counts = collections.Counter(state["counts"])
    if as_json is None:
        return state
    if as_json:
        print(json.dumps(state, indent=2))
        return state
    print_status(run, state, plan.get("displayLabels", {}))
    return state


def print_status(run, state, labels=None):
    counts = collections.Counter(state["counts"])
    duration = state["elapsedSeconds"]
    print("Run:", run)
    print("Scope:", state.get("validationScope", "full" if state.get("full") else "partial"))
    print(f"{state['phase']} | {duration // 3600:02}:{duration // 60 % 60:02}:{duration % 60:02} elapsed")
    stages = state.get("stageCounts", {})
    if stages and state.get("stageProgressRun"):
        print("Production progress for attempt", state["stageProgressRun"])
    for phase, title in (
        ("compile", "Compilation"), ("finalize", "Finalization"),
        ("build", "Unsplit builds"), ("prepare", "Assembly"),
    ):
        if phase not in stages:
            continue
        row = stages[phase]
        print(f"{title} {row['ready']}/{row['total']} ready ({row['cachedAtStart']} cached at start), "
              f"{row['bypassed']} covered by downstream outputs, {row['active']} active, {row['pending']} pending, "
              f"{row['failed-or-blocked']} failed/blocked, {row['cancelled']} cancelled")
    print(f"Suites: {counts['passed']}/{len(state['jobs'])} passed; {counts['failed-or-blocked']} failed/blocked; {counts['pending']} pending; {counts['cancelled']} cancelled")
    if state.get("testCounts"):
        tests = state["testCounts"]
        print(f"Tests/checks: {tests['passed']}/{sum(tests.values())} passed; {tests['failed-or-blocked']} failed/blocked; {tests['pending']} pending; {tests['cancelled']} cancelled")
    if state.get("retrySuites"):
        print(f"Latest retry results: {state['retrySuites']} suites across {len(state['attempts']) - 1} linked attempt(s).")
    print(f"Cached at start: {sum(x['cachedAtStart'] for x in state['jobs'].values())}; declared broken: {len(state.get('declaredBroken', []))}")
    if state.get("source"):
        print("Snapshot:", state.get("revision") or "uncommitted", Path(state["source"]).name)
    scripts = collections.Counter()
    labels = labels or {}
    for activity in state.get("active", {}).values():
        name = Path(activity["drv"]).name[33:].removesuffix(".drv")
        if (name.startswith("tvp-step-") and name.endswith(".sh")) or name == "tvp-build-step-runner":
            scripts[activity["phase"]] += 1
            continue
        label = labels.get(activity["drv"])
        if label and activity["phase"] == "fetching":
            label = label.rsplit(": ", 1)[0] + ": downloading cached result"
        print(f"  {label or name + ': ' + activity['phase']} ({int(time.time() - activity['startedAt'])}s)")
    if scripts:
        parts = []
        if scripts["building"]:
            parts.append(f"{scripts['building']} generating")
        if scripts["fetching"]:
            parts.append(f"{scripts['fetching']} downloading")
        parts.extend(f"{count} {phase}" for phase, count in scripts.items()
                     if phase not in {"building", "fetching"})
        print("  Build scripts: " + ", ".join(parts))
    if state["phase"] == "running":
        if state.get("operation") == "registering-roots":
            roots = state["rooting"]
            print(f"Registering GC roots: {roots['completed']}/{roots['total']} outputs protected")
        elif state.get("operation") == "checking-outputs":
            print("Checking completed outputs.")
        elif not state.get("active"):
            print("Waiting for Nix to finish.")
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
    print("Logs:", run / "nix.log", flush=True)


def progress_key(state):
    fields = {key: state.get(key) for key in (
        "phase", "operation", "counts", "testCounts", "stageCounts", "stageProgressRun",
        "rooting", "error", "monitorError",
        "retryErrors", "retrySuites")}
    fields["active"] = sorted((item["drv"], item["phase"]) for item in state.get("active", {}).values())
    fields["failed"] = sorted(name for name, job in state["jobs"].items()
                              if job["status"] == "failed-or-blocked")
    fields["attempts"] = len(state.get("attempts", []))
    return json.dumps(fields, sort_keys=True)


def print_ci(message):
    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    print(f"[{timestamp}] {message}", flush=True)


def ci_work(counts):
    local = counts.get("local", 0)
    remote = ", ".join(f"{key} {value}" for key, value in sorted(counts.items()) if key.startswith("remote "))
    return f"local {local}" + (", " + remote if remote else "") + f", downloads {counts.get('cache', 0)}"


def compact_progress(state):
    scope = state.get("validationScope", "smoke").capitalize()
    parts = [f"{scope} {state['phase']}"]
    if state.get("testCounts"):
        tests = state["testCounts"]
        parts.append(f"checks {tests['passed']}/{sum(tests.values())}")
        if tests["failed-or-blocked"]:
            parts.append(f"{tests['failed-or-blocked']} failed or blocked")
        if tests["cancelled"]:
            parts.append(f"{tests['cancelled']} cancelled")
    parts.append(f"suites {state['counts'].get('passed', 0)}/{len(state['jobs'])}"
                 f" ({sum(job['cachedAtStart'] for job in state['jobs'].values())} cached at start)")
    for phase, row in state.get("stageCounts", {}).items():
        covered = f", {row['bypassed']} covered" if row["bypassed"] else ""
        parts.append(f"{phase} {row['ready']}/{row['total']} ready{covered}")
    if state["phase"] in TERMINAL:
        if "activityStarts" in state:
            parts.append("Nix work started " + ci_work(state["activityStarts"]))
    else:
        builds, downloads = {}, set()
        for item in state.get("active", {}).values():
            note_activity(item, builds, downloads)
        counts = collections.Counter(builds.values())
        counts["cache"] = len(downloads)
        parts.append("active " + ci_work(counts))
        if state.get("operation") == "registering-roots":
            roots = state["rooting"]
            parts.append(f"protecting outputs {roots['completed']}/{roots['total']}")
        elif state.get("operation") == "checking-outputs":
            parts.append("checking outputs")
    if state.get("monitorError"):
        parts.append("progress query failed, see result.json")
    return " | ".join(parts)


def print_ci_failures(run, state, plan):
    failed_drvs = set(state.get("reportedFailedDerivations", []))
    failures = []
    for job in (plan or {}).get("jobs", []):
        if state["jobs"].get(job["name"], {}).get("status") != "failed-or-blocked":
            continue
        tests = [test["name"] for test in job.get("tests", []) if test["drv"] in failed_drvs]
        failures.extend(f"{job['name']}/{name}" for name in tests or ["blocked or failed"])
    if failures:
        extra = f", plus {len(failures) - 10} more" if len(failures) > 10 else ""
        print_ci("Failed or blocked " + ", ".join(failures[:10]) + extra)
    if state.get("error"):
        print_ci("Smoke error " + " ".join(state["error"].split()))
    print_ci(f"Details {run / 'nix.log'} and {run / 'result.json'}")


def wait(run, quiet=False, compact=False):
    previous, previous_phase, printed_at = None, None, None
    plan_path = run / "plan.json"
    plan = json.loads(plan_path.read_text()) if plan_path.exists() else None
    labels = (plan or {}).get("displayLabels", {})
    while True:
        # The worker publishes observations and rooting progress. Waiting on its
        # snapshot avoids a second process continually querying the same store.
        state = status(run, as_json=None, inspect_store=False, plan=plan)
        key, now = compact_progress(state) if compact else progress_key(state), time.monotonic()
        phase = state["phase"]
        if not quiet and compact:
            if (phase != previous_phase or now - printed_at >= 60
                    or key != previous and now - printed_at >= 15):
                duration = max(0, round(state.get("finishedAt", time.time())
                                        - state.get("buildStartedAt", state["startedAt"])))
                print_ci(f"+{duration}s | {key}")
                previous, previous_phase, printed_at = key, phase, now
            if phase in TERMINAL and phase != "passed":
                print_ci_failures(run, state, plan)
        elif not quiet and key != previous:
            print_status(run, state, labels)
            previous, printed_at = key, now
        elif not quiet and now - printed_at >= 60:
            operation = state.get("operation", state["phase"])
            label = {"registering-roots": "registering GC roots", "checking-outputs": "checking outputs"}.get(operation, operation)
            print(f"Still {label}; {state['elapsedSeconds']}s elapsed.", flush=True)
            printed_at = now
        if state["phase"] in TERMINAL:
            return 0 if state["phase"] == "passed" else 1
        time.sleep(1)


def positive(value):
    number = int(value)
    if number < 1:
        raise argparse.ArgumentTypeError("must be positive")
    return number


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "latest":
        from latest import main as latest_main
        return latest_main(sys.argv[2:])
    if len(sys.argv) > 1 and sys.argv[1] == "_work":
        return work(Path(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4]))
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("latest", help="freeze and supervise a resumable latest-only workflow")
    for name, help_text in (
        ("all", "run the standard installed-result checks and return success or failure"),
        ("start", "launch checks in the background (full upstream suites are opt-in)"),
    ):
        launch = commands.add_parser(name, help=help_text)
        launch.add_argument("--flake", default=".")
        launch.add_argument("--system", default=os.environ.get("TVP_TEST_SYSTEM", "x86_64-linux"))
        launch.add_argument("--state-dir", type=Path, default=Path(".tvp-tests"))
        launch.add_argument("--jobs", type=positive, help="override Nix's max-jobs setting")
        launch.add_argument("--cores", type=int, help="override Nix's cores setting (0 uses all cores)")
        launch.add_argument("--only", action="append", help="run only this exact suite name (repeatable)")
        scope = launch.add_mutually_exclusive_group()
        scope.add_argument("--smoke", action="store_true", help="select the standard installed-result plan explicitly")
        scope.add_argument("--full", action="store_true", help="explicitly run the full catalogue, including upstream suites")
        launch.add_argument("--retry-of", type=Path, help="link this run's results to an earlier run")
        launch.add_argument("--json", action="store_true", help="return the frozen run identity (all returns its terminal result)")
        launch.add_argument("--owner-lock", type=Path, help="stop if the controlling process releases this file lock")
    for name in ("status", "wait", "stop"):
        command = commands.add_parser(name, help=f"{name} a local validation run")
        command.add_argument("--state-dir", type=Path, default=Path(".tvp-tests"),
                             help="local state directory whose latest run is selected (default: .tvp-tests)")
        command.add_argument("--run", type=Path)
        if name == "status":
            command.add_argument("--json", action="store_true")
            command.add_argument("--attempt-only", action="store_true", help="show this frozen attempt without linked retries")
    from verifier import add_parser, dispatch
    add_parser(commands)
    from representative import add_parser as add_representative, dispatch as dispatch_representative
    add_representative(commands)
    from batch_report import add_parser as add_report, dispatch as dispatch_report
    add_report(commands)
    args = parser.parse_args()
    try:
        if args.command == "report":
            return dispatch_report(args)
        if args.command == "verify":
            return dispatch(args)
        if args.command == "verify-representative":
            return dispatch_representative(args)
        if args.command == "start":
            return start(args)
        if args.command == "all":
            return run_all(args)
        run = (args.run or args.state_dir / "latest").resolve()
        if not (run / "state.json").is_file():
            raise RuntimeError(f"No local validation run found at {run}.\n"
                               "Use --state-dir DIR or --run PATH to select an existing run, "
                               "or 'start' to launch one. Server CI builds are shown in Buildbot.")
        if args.command == "stop":
            state = json.loads((run / "state.json").read_text())
            if not lease_held(run / "worker.lock") or not state.get("pid"):
                raise RuntimeError("This run has no active worker")
            os.kill(state["pid"], signal.SIGTERM)
            print("Stopping:", run)
            return 0
        if args.command == "wait":
            return wait(run)
        status(run, args.json, args.attempt_only)
        return 0
    except (OSError, RuntimeError, ValueError, subprocess.SubprocessError) as error:
        print(str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())

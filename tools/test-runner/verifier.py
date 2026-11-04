"""Read-only certification of one frozen, terminal full test attempt."""

import argparse
import collections
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import re
import socket
import subprocess
import tempfile

from graph_compare import compare, read_snapshot

SCHEMA = "tvp.validation-report/v1"
STORE = re.compile(r"/nix/store/[a-z0-9]{32}-[^/\s]+\Z")
NAME = re.compile(r"[A-Za-z0-9][A-Za-z0-9._+-]*\Z")
SHA = re.compile(r"[0-9a-f]{40}\Z")
STATUSES = ("passed", "failed-or-blocked", "pending", "cancelled")


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, "Duplicate JSON key: " + key)
        result[key] = value
    return result


def load(path):
    return json.loads(Path(path).read_text(), object_pairs_hook=unique_object)


def atomic_report(path, report, inputs):
    """Create immutable evidence with no clobber, including competing writers."""
    path = Path(path).absolute()
    require(all(path.resolve() != Path(p).resolve() for p in inputs), "Output aliases an input")
    require(all(digest(p) == h for p, h in inputs.items()), "Input hash changed before report publication")
    data = (json.dumps(report, indent=2, sort_keys=True) + "\n").encode()
    if path.exists() or path.is_symlink():
        require(not path.is_symlink() and path.read_bytes() == data, "Conflicting report already exists")
        return
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as stream:
            temporary = stream.name
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.link(temporary, path)
    finally:
        if temporary:
            os.unlink(temporary)


def store_path(value, drv=False):
    require(isinstance(value, str) and STORE.fullmatch(value), "Invalid store path: " + repr(value))
    require(value.endswith(".drv") == drv, "Wrong store path kind: " + value)


def names(rows, label):
    require(isinstance(rows, list), label + " must be a list")
    seen = set()
    for row in rows:
        require(isinstance(row, dict), label + " row must be an object")
        name = row.get("name")
        require(isinstance(name, str) and NAME.fullmatch(name), "Unsafe " + label + " name")
        require(name not in seen, "Duplicate " + label + " name: " + name)
        seen.add(name)


def validate_plan(plan):
    require(isinstance(plan, dict) and type(plan.get("schema")) is int and plan["schema"] == 1,
            "Unsupported plan schema")
    require(set(plan) == {"schema", "revision", "source", "system", "aggregate", "jobs", "skipped"},
            "Unsupported plan fields")
    require(isinstance(plan["revision"], str) and SHA.fullmatch(plan["revision"]), "Full frozen revision required")
    require(isinstance(plan["system"], str) and NAME.fullmatch(plan["system"]), "Invalid system")
    store_path(plan["source"])
    store_path(plan["aggregate"], drv=True)
    names(plan["jobs"], "suite")
    require(plan["jobs"], "Empty plan")
    for job in plan["jobs"]:
        require(set(job) == {"name", "drv", "outputs", "tests"}, "Unsupported suite fields")
        names(job["tests"], "test")
        for item in [job] + job["tests"]:
            require(set(item) == ({"name", "drv", "outputs", "tests"} if item is job else
                                  {"name", "drv", "outputs"}), "Unsupported test fields")
            store_path(item["drv"], drv=True)
            outputs = item["outputs"]
            require(isinstance(outputs, list) and outputs and len(set(outputs)) == len(outputs),
                    "Outputs must be a nonempty unique list")
            for output in outputs:
                store_path(output)
    names(plan["skipped"], "exclusion")
    for row in plan["skipped"]:
        require(set(row) == {"name", "reason"} and isinstance(row["reason"], str) and row["reason"].strip(),
                "Invalid exclusion reason")
    named = [test for job in plan["jobs"] for test in job["tests"]]
    checks = sum(not job["tests"] for job in plan["jobs"])
    return {"suites": len(plan["jobs"]), "namedOccurrences": len(named),
            "uniqueNamedDRVs": len({test["drv"] for test in named}), "checks": checks,
            "results": len(named) + checks, "exclusions": len(plan["skipped"])}


def number(value):
    return type(value) in (int, float) and math.isfinite(value)


def passed_counts(counts, expected):
    return (isinstance(counts, dict) and set(counts) == set(STATUSES)
            and all(type(v) is int and v >= 0 for v in counts.values())
            and counts == dict.fromkeys(STATUSES[1:], 0) | {"passed": expected})


def validate_state(plan, state, adapter):
    require(isinstance(state, dict), "State must be an object")
    require(not any(k in state for k in ("attempts", "retrySuites", "retryErrors", "retryOf")),
            "Combined/retry evidence cannot certify one original attempt")
    require(state.get("phase") == "passed" and type(state.get("returnCode")) is int
            and state["returnCode"] == 0 and state.get("full") is True, "Expected passed/returnCode 0/full")
    require(state.get("cancelled") is False and state.get("active") == {}, "Cancellation or active work")
    require(not any(state.get(k) for k in ("error", "monitorError", "cancelReason")), "Worker/monitor error")
    require(state.get("reportedFailedDerivations") == [], "Reported failed derivations missing/nonempty")
    for field in ("startedAt", "buildStartedAt", "updatedAt", "finishedAt"):
        require(number(state.get(field)), "Missing/invalid " + field)
    require(state["startedAt"] <= state["buildStartedAt"] <= state["finishedAt"]
            and state["buildStartedAt"] <= state["updatedAt"]
            and (adapter == "ci-status" or state["updatedAt"] <= state["finishedAt"]),
            "Inconsistent terminal times")
    require(type(state.get("pid")) is int and state["pid"] > 0, "Missing/invalid worker PID")
    require(isinstance(state.get("jobs"), dict) and set(state["jobs"]) == {j["name"] for j in plan["jobs"]},
            "State suite membership differs")
    for job in plan["jobs"]:
        entry = state["jobs"][job["name"]]
        require(isinstance(entry, dict) and set(entry) == {"status", "cachedAtStart", "completedAt", "tests"},
                "Unsupported/missing per-job reporting: " + job["name"])
        require(entry["status"] == "passed" and type(entry["cachedAtStart"]) is bool,
                "Invalid per-job status/cache flag: " + job["name"])
        require(number(entry["completedAt"]) and state["startedAt"] <= entry["completedAt"] <= min(state["updatedAt"], state["finishedAt"]),
                "Invalid completion time: " + job["name"])
        require(passed_counts(entry["tests"], len(job["tests"]) or 1), "Per-job result counts differ: " + job["name"])
    total = sum(len(j["tests"]) or 1 for j in plan["jobs"])
    require(passed_counts(state.get("testCounts"), total), "Global test counts differ")
    if adapter == "ci-status":
        require(state.get("source") == plan["source"] and state.get("declaredBroken") == plan["skipped"],
                "Exported source/exclusions differ")
        require(isinstance(state.get("run"), str) and Path(state["run"]).is_absolute(), "Exported run missing")
        require(state.get("counts") == {"passed": len(plan["jobs"])}, "Exported suite counts differ")
    else:
        require(adapter == "raw", "Unsupported state adapter")
    # Optional derived fields must agree even when supplied with raw evidence.
    for key, expected in (("source", plan["source"]), ("declaredBroken", plan["skipped"]),
                          ("counts", {"passed": len(plan["jobs"])})):
        require(key not in state or state[key] == expected, "Contradictory " + key)


class Store:
    """Only immutable derivation reads and batched validity queries; no evaluation."""

    def derivations(self, paths):
        result = {}
        paths = sorted(set(paths))
        for offset in range(0, len(paths), 128):
            argv = ["nix", "derivation", "show"] + paths[offset:offset + 128]
            doc = json.loads(subprocess.check_output(argv, text=True, timeout=120))
            require(isinstance(doc, dict), "Malformed derivation response")
            rows = doc.get("derivations", doc)
            require(isinstance(rows, dict), "Malformed derivation rows")
            for value in rows.values():
                require(isinstance(value, dict) and isinstance(value.get("outputs"), dict),
                        "Malformed derivation metadata")
                for output in value.get("outputs", {}).values():
                    require(isinstance(output, dict), "Malformed output metadata")
                    path = output.get("path")
                    if isinstance(path, str) and not path.startswith("/"):
                        output["path"] = "/nix/store/" + path
            result.update({"/nix/store/" + Path(k).name: v for k, v in rows.items()})
        require(set(result) == set(paths), "Incomplete derivation observation")
        return result

    def valid(self, paths):
        paths = set(paths)
        result = subprocess.run(["nix-store", "--check-validity", "--print-invalid", "--stdin"],
                                input="\n".join(sorted(paths)) + "\n", text=True, capture_output=True, timeout=120)
        invalid = set(result.stdout.splitlines())
        require(result.returncode in (0, 1) and invalid <= paths
                and (result.returncode == 0 or invalid), "Store validity query failed: " + result.stderr)
        require(result.returncode != 0 or not invalid, "Contradictory store validity response")
        return paths - invalid


def observe_store(plan, supplied, store):
    items = [item for j in plan["jobs"] for item in [j] + j["tests"]]
    expected = {}
    for item in items:
        previous = expected.setdefault(item["drv"], item["outputs"])
        require(set(previous) == set(item["outputs"]), "Conflicting outputs for shared derivation")
    drvs = store.derivations([plan["aggregate"]] + list(expected))
    for drv, outputs in expected.items():
        metadata = drvs[drv]
        actual = [o.get("path") for o in metadata["outputs"].values()]
        require(set(actual) == set(outputs), "Declared derivation outputs differ: " + drv)
        require(metadata["system"] == plan["system"], "Derivation system differs: " + drv)
    aggregate_outputs = [o.get("path") for o in drvs[plan["aggregate"]]["outputs"].values()]
    require(len(aggregate_outputs) == 1, "Unsupported aggregate outputs")
    aggregate = aggregate_outputs[0]
    store_path(aggregate)
    require(drvs[plan["aggregate"]]["system"] == plan["system"], "Aggregate system differs")
    require(supplied is None or str(supplied) == aggregate, "Supplied aggregate unrelated to plan")
    outputs = {p for values in expected.values() for p in values} | {aggregate, plan["source"]}
    require(store.valid(outputs) == outputs, "Missing/invalid declared output or source")
    links = 0

    def directory(path, rows):
        nonlocal links
        require(path.is_dir() and {p.name for p in path.iterdir()} == {r["name"] for r in rows},
                "Directory membership differs: " + str(path))
        for row in rows:
            link = path / row["name"]
            require(link.is_symlink() and os.readlink(link) == row["outputs"][0] and link.exists(),
                    "Wrong/broken/non-symlink link: " + str(link))
            links += 1

    directory(Path(aggregate), plan["jobs"])
    for job in plan["jobs"]:
        if job["tests"]:
            directory(Path(job["outputs"][0]), job["tests"])
    return {"drv": plan["aggregate"], "outputs": aggregate_outputs}, links, len(outputs)


def worker_observation(run, state):
    if run is None:
        return {"status": "unavailable", "reason": "Exported state; worker lock/process not local"}
    lock = run / "worker.lock"
    # Do not create a lock or use runner.lease_held (which opens with 'a').
    with lock.open("rb") as stream:
        try:
            fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise ValueError("Worker lock still held") from None
        cmd = Path("/proc") / str(state["pid"]) / "cmdline"
        command = cmd.read_bytes().split(b"\0") if cmd.exists() else []
        require(not (b"_work" in command and os.fsencode(str(run)) in command), "Bound worker still live")
    return {"status": "passed", "workerLock": str(lock), "recordedPid": state["pid"],
            "recordedPidExists": bool(command), "boundWorkerLive": False}


def execution(state, log, prepare):
    result = {"cachedAtStart": sum(j["cachedAtStart"] for j in state["jobs"].values())}
    for key, path, pattern in (("loggedActivity", log, r"^(building|fetching) (\S+)"),
                               ("preparation", prepare, r"^(building|fetching) ['\"]?(/nix/store/[^'\"\s]+)")):
        result[key] = ({"status": "observed", "events": re.findall(pattern, path.read_text(), re.M)}
                       if path else {"status": "unavailable"})
    return result


def verify(args, store=None):
    report = {"schema": SCHEMA, "result": "FAIL", "checks": [], "inputs": {},
              "observationHost": socket.gethostname(), "limitations": [
                  "Store observation proves current availability and links, not fresh test execution.",
                  "No recipe approval, ABI compatibility, content scrub, signatures or retention certification."]}
    inputs = report["inputs"]

    def read(path):
        path = Path(path).absolute()
        before = digest(path)
        value = load(path)
        require(digest(path) == before, "Input changed during read: " + str(path))
        inputs[str(path)] = before
        return value

    def check(name, action):
        try:
            value = action()
            report["checks"].append({"name": name, "status": "passed"})
            return value
        except (ValueError, OSError, KeyError, TypeError, subprocess.SubprocessError) as error:
            report["checks"].append({"name": name, "status": "failed", "error": str(error)})
            raise

    try:
        run = args.run.absolute() if args.run else None
        require(not run or (not args.plan and not args.state and run.resolve() == run),
                "Use canonical --run OR explicit --plan/--state")
        plan_path, state_path = ((run / "plan.json", run / "state.json") if run else (args.plan, args.state))
        require(plan_path and state_path, "Plan and state required")
        plan, state = read(plan_path), read(state_path)
        report["counts"] = check("plan", lambda: validate_plan(plan))
        report["subject"] = {k: plan[k] for k in ("revision", "source", "system")}
        check("state", lambda: validate_state(plan, state, args.adapter))
        for key in ("revision", "source", "system"):
            wanted = getattr(args, "expect_" + key)
            if wanted:
                check("expected-" + key, lambda k=key, w=wanted: require(plan[k] == w, "Expected " + k + " differs"))
        if args.reference_plan:
            reference = read(args.reference_plan)
            check("reference-schema", lambda: validate_plan(reference))
            candidate = dict(plan)
            if args.revision_only:
                candidate["revision"] = reference["revision"]
            check("reviewed-plan", lambda: require(candidate == reference, "Reviewed plan differs"))
            report["reference"] = {"mode": "revision-only" if args.revision_only else "exact",
                                   "revision": reference["revision"]}
        else:
            require(not args.revision_only, "Revision-only requires reference plan")
            report["reference"] = {"status": "unavailable"}
        report["worker"] = check("worker", lambda: worker_observation(run, state))
        aggregate, links, output_count = check("store-and-links", lambda: observe_store(plan, args.aggregate, store or Store()))
        if run:
            def result_link():
                result = run / "result"
                require(result.is_symlink() and os.readlink(result) == aggregate["outputs"][0]
                        and result.exists(), "Run result link differs from intended aggregate")
                require("run" not in state or state["run"] == str(run), "State run identity differs")
            check("run-result", result_link)
            report["subject"]["run"] = str(run)
        report["subject"]["aggregate"] = aggregate
        report["counts"]["verifiedLinks"] = links
        report["coverage"] = {"declaredOutputsAndSource": output_count, "actualLocalStoreObservation": True,
                              "primaryOutputLinks": links, "allDeclaredMultioutputs": True}
        for label, path in (("log", args.log or (run / "nix.log" if run else None)),
                            ("prepare", args.prepare_log or (run / "prepare.log" if run else None))):
            if path and Path(path).is_file():
                inputs[str(Path(path).absolute())] = digest(path)
            else:
                path = None
            if label == "log":
                log = path
            else:
                prepare = path
        report["execution"] = execution(state, log, prepare)
        require(bool(args.graph_before) == bool(args.graph_after), "Both graph snapshots required")
        report["graphDelta"] = None
        if args.graph_before:
            # Read through the stable input adapter, then use existing graph semantics.
            for path in (args.graph_before, args.graph_after):
                graph = read(path)
                require(isinstance(graph, dict) and type(graph.get("schema")) is int
                        and graph["schema"] == 1 and isinstance(graph.get("entries"), dict),
                        "Unsupported graph shape")
            before, after = read_snapshot(args.graph_before), read_snapshot(args.graph_after)
            report["graphDelta"] = compare(before, after)
            report["graphDelta"]["informational"] = True
        if args.invariants:
            policy = read(args.invariants)
            require(isinstance(policy, dict)
                    and set(policy) <= {"schema", "graphDelta", "graphEntries", "planJobs", "skipped"}
                    and type(policy.get("schema")) is int and policy["schema"] == 1,
                    "Unsupported invariant policy")
            for field in ("graphEntries", "planJobs"):
                require(field not in policy or isinstance(policy[field], dict), "Invalid invariant " + field)
            if "graphDelta" in policy:
                require(isinstance(policy["graphDelta"], dict) and args.graph_before,
                        "Expected graph delta requires snapshots and an object")
                check("expected-graph-delta", lambda: require(report["graphDelta"] == policy["graphDelta"], "Graph delta differs"))
            for name, value in policy.get("graphEntries", {}).items():
                require(isinstance(value, dict) and all(isinstance(value.get(k), str) and value[k]
                        for k in ("drv", "out")), "Invalid graph invariant identity")
                check("graph-entry:" + name, lambda n=name, v=value: require(args.graph_after and n in after and after[n] == v, "Graph invariant differs"))
            indexed = {j["name"]: j for j in plan["jobs"]}
            for name, value in policy.get("planJobs", {}).items():
                require(isinstance(value, dict) and value.get("name") == name, "Invalid plan invariant identity")
                validate_plan(plan | {"jobs": [value]})
                check("plan-job:" + name, lambda n=name, v=value: require(n in indexed and indexed[n] == v, "Plan invariant differs"))
            if "skipped" in policy:
                validate_plan(plan | {"skipped": policy["skipped"]})
                check("exclusions", lambda: require(plan["skipped"] == policy["skipped"], "Exclusions differ"))
        check("input-stability", lambda: require(all(digest(p) == h for p, h in inputs.items()), "Input hash changed"))
        report["result"] = "PASS"
    except (ValueError, OSError, KeyError, TypeError, subprocess.SubprocessError) as error:
        report["failure"] = str(error)
        if not any(c["status"] == "failed" for c in report["checks"]):
            report["checks"].append({"name": "evidence", "status": "failed", "error": str(error)})
    return report


def add_parser(commands):
    parser = commands.add_parser("verify", help=__doc__)
    for name in ("run", "plan", "state", "aggregate", "reference-plan", "graph-before", "graph-after", "invariants", "log", "prepare-log"):
        parser.add_argument("--" + name, type=Path)
    parser.add_argument("--adapter", choices=("raw", "ci-status"), default="raw")
    parser.add_argument("--revision-only", action="store_true")
    for name in ("revision", "source", "system"):
        parser.add_argument("--expect-" + name)
    parser.add_argument("--output", type=Path, required=True)


def dispatch(args):
    report = verify(args)
    atomic_report(args.output, report, report["inputs"])
    print(json.dumps({"result": report["result"], "report": str(args.output), "failure": report.get("failure")}))
    return int(report["result"] != "PASS")

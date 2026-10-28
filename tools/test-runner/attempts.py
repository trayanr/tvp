"""Combine explicitly linked retries while retaining each frozen attempt."""

import collections
import fcntl
import json
from pathlib import Path
import time

from progress import members, save


TERMINAL = {"passed", "failed", "cancelled", "error", "interrupted"}


def linked_runs(run, seen=None):
    seen = set() if seen is None else seen
    run = run.resolve()
    if run in seen:
        raise RuntimeError("Cyclic or duplicate retry link: " + str(run))
    seen.add(run)
    yield run
    links = run / "retries.json"
    for path in json.loads(links.read_text()) if links.exists() else []:
        yield from linked_runs(Path(path), seen)


def register_retry(parent, retry):
    parent, retry = parent.resolve(), retry.resolve()
    if parent in set(linked_runs(retry)):
        raise RuntimeError("A retry cannot contain its parent")
    original = json.loads((parent / "plan.json").read_text())
    plan = json.loads((retry / "plan.json").read_text())
    if original.get("system") != plan.get("system"):
        raise RuntimeError("A retry must use the same platform")
    names = {job["name"] for job in original["jobs"]}
    if not plan["jobs"] or not {job["name"] for job in plan["jobs"]}.issubset(names):
        raise RuntimeError("A retry must select suites from its parent")
    with (parent / "retries.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        links = parent / "retries.json"
        paths = json.loads(links.read_text()) if links.exists() else []
        if retry not in set(linked_runs(parent)):
            save(links, paths + [str(retry)])


def combine(run, original, snapshot):
    paths = list(linked_runs(run))
    if len(paths) == 1:
        return original
    attempts = [(run, original)] + [(path, snapshot(path)) for path in paths[1:]]
    # Explicit links allow changed recipes; independent runs are never matched
    # just because they happen to contain the same package names.
    attempts.sort(key=lambda item: item[1]["startedAt"])
    jobs = dict(original["jobs"])
    selected = {name: run for name in jobs}
    histories, active, errors = [], {}, set()
    for path, state in attempts:
        histories.append({key: state[key] for key in (
            "run", "phase", "counts", "source", "returnCode", "error", "monitorError",
            "reportedFailedDerivations",
        ) if key in state})
        for name, job in state["jobs"].items():
            if name in jobs:
                jobs[name] = dict(job, cachedAtStart=original["jobs"][name]["cachedAtStart"],
                                  attempt=str(path))
                selected[name] = path
        for activity in state.get("active", {}).values():
            active[activity["drv"]] = activity
    for path, state in attempts:
        plan = json.loads((path / "plan.json").read_text())
        for job in members(plan, path):
            name = job["name"]
            if selected.get(name) == path and jobs[name]["status"] == "failed-or-blocked":
                relevant = {job["drv"]} | {test["drv"] for test in job.get("tests", [])}
                errors.update(relevant.intersection(state.get("reportedFailedDerivations", [])))
    result = dict(original, jobs=jobs, active=active, attempts=histories,
                  reportedFailedDerivations=sorted(errors), retrySuites=sum(path != run for path in selected.values()))
    result["retryErrors"] = [
        {"run": str(path), "error": state.get("error") or state["monitorError"]}
        for path, state in attempts if path != run and path in selected.values()
        and (state.get("error") or state.get("monitorError"))
    ]
    result["counts"] = dict(collections.Counter(job["status"] for job in jobs.values()))
    tests = collections.Counter()
    for job in jobs.values():
        tests.update(job.get("tests", {job["status"]: 1}))
    result["testCounts"] = {key: tests[key] for key in ("passed", "failed-or-blocked", "pending", "cancelled")}
    running = any(state["phase"] not in TERMINAL for _, state in attempts)
    if running:
        result["phase"] = "running"
    elif all(job["status"] == "passed" for job in jobs.values()):
        result["phase"] = "passed"
    elif any(job["status"] == "failed-or-blocked" for job in jobs.values()):
        result["phase"] = "failed"
    elif any(job["status"] == "cancelled" for job in jobs.values()):
        result["phase"] = "cancelled"
    else:
        # A terminal retry cannot make unresolved work from another attempt
        # successful. Keep infrastructure failures visible to `wait` as well.
        result["phase"] = "error" if any(state["phase"] == "error" for _, state in attempts) else "interrupted"
    end = time.time() if running else max(state.get("finishedAt", time.time()) for _, state in attempts)
    result["elapsedSeconds"] = round(end - original["startedAt"])
    if running:
        result.pop("finishedAt", None)
    else:
        result["finishedAt"] = end
    # A process exit describes one attempt, not the combined validation result.
    result.pop("returnCode", None)
    if result["phase"] == "passed":
        result.pop("error", None)
    return result

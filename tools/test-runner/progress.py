"""Observe test outputs and reported failures without scheduling any builds."""

import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import tempfile
import time


FAILED_DRV = re.compile(
    r"(?:Cannot build|cannot build|builder for) ['\"](/nix/store/[^'\"\s]+\.drv)['\"]"
)
STAGE_PHASES = ("compile", "finalize", "build", "prepare")
STAGE_RESULTS = ("ready", "bypassed", "active", "pending", "failed-or-blocked", "cancelled")


def save(path, value):
    with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as stream:
        temporary = stream.name
        json.dump(value, stream)
    os.replace(temporary, path)


def valid_paths(paths):
    paths = set(paths)
    result = subprocess.run(
        ["nix-store", "--check-validity", "--print-invalid", "--stdin"],
        input="\n".join(sorted(paths)) + "\n", text=True, capture_output=True,
    )
    if result.returncode not in (0, 1):
        raise RuntimeError(result.stderr.strip())
    invalid = set(result.stdout.splitlines())
    if result.returncode and not invalid:
        raise RuntimeError(result.stderr.strip() or "Nix store validity check failed")
    if not invalid.issubset(paths):
        raise RuntimeError("Unexpected Nix store validity response")
    return paths - invalid


def root_path(link, target):
    subprocess.run(
        ["nix-store", "--add-root", str(link), "--indirect", "--realise", str(target)],
        check=True, stdout=subprocess.DEVNULL,
    )


def root_paths(run, paths, protected=None, on_progress=None):
    protected = set() if protected is None else protected
    paths = set(paths)
    pending = sorted(paths - protected)
    if not pending:
        return
    if on_progress:
        on_progress(len(paths & protected), len(paths))
    for offset in range(0, len(pending), 1024):
        chunk = pending[offset:offset + 1024]
        # Keep these names: Nix's indirect GC roots point back to them.
        # A partial failure can safely retry the same deterministic batch.
        identifier = hashlib.sha256("\n".join(chunk).encode()).hexdigest()
        subprocess.run(
            ["nix-store", "--add-root", str(run / "roots" / ("completed-" + identifier)),
             "--indirect", "--realise", "--stdin", "--max-jobs", "0",
             "--option", "builders", "", "--option", "substituters", ""],
            input="\n".join(chunk) + "\n", text=True, check=True, stdout=subprocess.DEVNULL,
        )
        protected.update(chunk)
        if on_progress:
            on_progress(len(paths & protected), len(paths))


def members(plan, run):
    if all("tests" in job for job in plan["jobs"]):
        return plan["jobs"]
    # Plans made before member metadata existed remain inspectable. Recover the
    # links from our own linkFarm builder, without evaluating a changed checkout.
    cache = run / "progress-plan.json"
    if cache.exists():
        return json.loads(cache.read_text())
    candidates = [job for job in plan["jobs"] if any(
        Path(out).name[33:].startswith("tvp-tests-") for out in job["outputs"]
    )]
    if not candidates:
        return plan["jobs"]
    result = subprocess.run(
        ["nix", "derivation", "show"] + [job["drv"] for job in candidates],
        text=True, capture_output=True, check=True,
    )
    document = json.loads(result.stdout)
    derivations = document.get("derivations", document)
    indexed = {Path(key).name: value for key, value in derivations.items()}
    jobs = []
    for job in plan["jobs"]:
        job = dict(job)
        drv = indexed.get(Path(job["drv"]).name, {})
        inputs = drv.get("inputDrvs", drv.get("inputs", {}).get("drvs", {}))
        by_name = {Path(key).name[33:-4]: key for key in inputs}
        tests = []
        for line in drv.get("env", {}).get("buildCommand", "").splitlines():
            if not line.startswith("ln -s "):
                continue
            words = shlex.split(line)
            if len(words) != 4 or not words[2].startswith("/nix/store/"):
                raise RuntimeError("Unrecognised legacy suite member")
            output, name = words[2:]
            dependency = by_name.get(Path(output).name[33:])
            if dependency is None:
                raise RuntimeError("Cannot identify legacy suite member: " + output)
            tests.append({"name": name, "drv": "/nix/store/" + Path(dependency).name,
                          "outputs": [output]})
        job["tests"] = tests
        jobs.append(job)
    save(cache, jobs)
    return jobs


def failures(run):
    cache = run / "progress-errors.json"
    with (run / "progress-errors.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        previous = json.loads(cache.read_text()) if cache.exists() else {"offset": 0, "drvs": []}
        failed = set(previous["drvs"])
        log = run / "nix.log"
        if log.exists():
            with log.open("rb") as stream:
                if log.stat().st_size < previous["offset"]:
                    previous = {"offset": 0}
                    failed.clear()
                stream.seek(previous["offset"])
                while line := stream.readline():
                    # A concurrently written last line is read on the next query.
                    if not line.endswith(b"\n"):
                        stream.seek(-len(line), 1)
                        break
                    text = line.decode("utf-8", errors="replace")
                    if text.startswith("error:"):
                        failed.update(FAILED_DRV.findall(text))
                previous["offset"] = stream.tell()
        previous["drvs"] = sorted(failed)
        save(cache, previous)
    return failed


def production_stages(jobs):
    """Group selected production work by exact derivation, retaining each use."""
    stages = {}
    for job in jobs:
        for producer in job.get("productions", []):
            role = producer["role"]
            phase = "compile" if role == "artifact" else "finalize" if len(job["productions"]) > 1 else "build"
            stage = stages.setdefault(producer["drv"], {"phase": phase, "outputs": set(), "uses": set()})
            outputs = frozenset(producer["outputs"].values())
            stage["phase"] = phase
            stage["outputs"].update(outputs)
            # Catalogue production is required even when every check is cached.
            stage["uses"].add((outputs, frozenset()))
        if not job.get("stages"):
            continue
        tests = {test["drv"]: test["outputs"] for test in job.get("tests") or [job]}
        for row in job["stages"]:
            drv, phase = row["drv"], row["phase"]
            stage = stages.setdefault(drv, {"phase": phase, "outputs": set(), "uses": set()})
            # The same artifact can be exposed as a raw, unsplit test subject.
            # Prefer its explicit role when another use names that boundary.
            if stage["phase"] == "build" or phase == "compile":
                stage["phase"] = phase
            outputs = frozenset(row["outputs"])
            checked = frozenset(path for test in row.get("tests", tests) for path in tests[test])
            covers = frozenset(frozenset(group) for group in row.get("coveredBy", []) if group)
            if checked:
                covers |= {checked}
            stage["outputs"].update(outputs)
            stage["uses"].add((outputs, covers))
    return stages


def production_paths(job):
    return {path for producer in job.get("productions", []) for path in producer["outputs"].values()}


def observed_paths(jobs, stages):
    """Read stage and test availability in one store query."""
    paths = {output for job in jobs for test in job.get("tests") or [job] for output in test["outputs"]}
    for stage in stages.values():
        paths.update(stage["outputs"])
        paths.update(path for _, covers in stage["uses"] for group in covers for path in group)
    return paths


def stage_counts(stages, present, state, failed=(), final=False):
    active = {item["drv"] for item in state.get("active", {}).values()}
    previous = state.get("stageCounts", {})
    counts = {phase: dict.fromkeys(STAGE_RESULTS, 0) | {
        "total": 0, "cachedAtStart": previous.get(phase, {}).get("cachedAtStart", 0),
    } for phase in STAGE_PHASES}
    for drv, stage in stages.items():
        outputs = stage["outputs"]
        if outputs <= present:
            result = "ready"
        elif not final and (drv in active or outputs & active):
            result = "active"
        elif all(paths <= present or any(group <= present for group in covers)
                 for paths, covers in stage["uses"]):
            result = "bypassed"
        elif drv in failed or final:
            result = "cancelled" if drv not in failed and state.get("cancelled") else "failed-or-blocked"
        else:
            result = "pending"
        counts[stage["phase"]][result] += 1
        counts[stage["phase"]]["total"] += 1
    return {phase: row for phase, row in counts.items() if row["total"]}


def observe(plan, state, run, final=False, root_completed=True, protected=None, on_roots=None,
            stages=None):
    jobs = members(plan, run)
    stages = production_stages(jobs) if stages is None else stages
    present = valid_paths(observed_paths(jobs, stages))
    failed = failures(run)
    if stages:
        state["stageCounts"] = stage_counts(stages, present, state, failed=failed, final=final)
    counts = {"passed": 0, "failed-or-blocked": 0, "pending": 0, "cancelled": 0}
    completed = set()
    for job in jobs:
        entry = state["jobs"][job["name"]]
        tests = job.get("tests") or [job]
        required = production_paths(job)
        results = []
        for test in tests:
            if all(output in present for output in test["outputs"]):
                result = "passed"
            elif test["drv"] in failed:
                result = "failed-or-blocked"
            elif final:
                result = "cancelled" if state.get("cancelled") else "failed-or-blocked"
            else:
                result = "pending"
            counts[result] += 1
            results.append(result)
            if result == "passed":
                completed.update(test["outputs"])
        if required <= present and all(result == "passed" for result in results):
            entry.update(status="passed")
            entry.setdefault("completedAt", time.time())
        elif (job["drv"] in failed or "failed-or-blocked" in results
              or any(producer["drv"] in failed for producer in job.get("productions", []))
              or (final and not state.get("cancelled") and not required <= present)):
            entry["status"] = "failed-or-blocked"
        elif "cancelled" in results or (final and state.get("cancelled") and not required <= present):
            entry["status"] = "cancelled"
        else:
            entry["status"] = "pending"
        entry["tests"] = {key: results.count(key) for key in counts}
        completed.update(required & present)
    state["testCounts"] = counts
    state["reportedFailedDerivations"] = sorted(failed)
    state["updatedAt"] = time.time()
    if root_completed:
        root_paths(run, completed, protected=protected, on_progress=on_roots)

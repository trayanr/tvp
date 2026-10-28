"""Observe test outputs and reported failures without scheduling any builds."""

import fcntl
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


def observe(plan, state, run, final=False, root_completed=True):
    jobs = members(plan, run)
    units = [test for job in jobs for test in (job.get("tests") or [job])]
    present = valid_paths(output for unit in units for output in unit["outputs"])
    failed = failures(run)
    counts = {"passed": 0, "failed-or-blocked": 0, "pending": 0, "cancelled": 0}
    for job in jobs:
        entry = state["jobs"][job["name"]]
        tests = job.get("tests") or [job]
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
        if root_completed:
            index = 0
            for test, result in zip(tests, results):
                for output in test["outputs"]:
                    link = run / "roots" / (job["name"] + f"-test-{index}")
                    if result == "passed" and not link.is_symlink():
                        root_path(link, output)
                    index += 1
        if all(result == "passed" for result in results):
            entry.update(status="passed")
            entry.setdefault("completedAt", time.time())
        elif job["drv"] in failed or "failed-or-blocked" in results:
            entry["status"] = "failed-or-blocked"
        elif "cancelled" in results:
            entry["status"] = "cancelled"
        else:
            entry["status"] = "pending"
        entry["tests"] = {key: results.count(key) for key in counts}
    state["testCounts"] = counts
    state["reportedFailedDerivations"] = sorted(failed)
    state["updatedAt"] = time.time()

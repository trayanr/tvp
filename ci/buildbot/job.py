#!/usr/bin/env python3
"""Trusted worker harness: exact PR head, current target gate, frozen full suite."""
import argparse
import fcntl
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys


def execute(argv, **kwargs):
    return subprocess.run(argv, check=True, **kwargs)


def checkout(repository, revision, destination):
    if not re.fullmatch(r"[0-9a-f]{40}", revision):
        raise ValueError("A full immutable commit SHA is required")
    destination.mkdir(parents=True)
    execute(["git", "init", "--quiet", str(destination)])
    execute(["git", "-C", str(destination), "-c", "core.hooksPath=/dev/null",
             "fetch", "--no-tags", f"https://github.com/{repository}.git", revision])
    execute(["git", "-C", str(destination), "checkout", "--detach", revision])
    actual = subprocess.check_output(["git", "-C", str(destination), "rev-parse", "HEAD"], text=True).strip()
    if actual != revision:
        raise ValueError("Checkout does not match the scheduled commit")


def wait_for_run(runner, run):
    def stop(_signal, _frame):
        subprocess.run([str(runner), "stop", "--run", str(run)], check=False)
    previous = {sig: signal.signal(sig, stop) for sig in (signal.SIGTERM, signal.SIGINT)}
    try:
        return subprocess.run([str(runner), "wait", "--run", str(run)])
    finally:
        for sig, handler in previous.items():
            signal.signal(sig, handler)


def require_current_target(repository, candidate, base, head, branch):
    if not re.fullmatch(r"[0-9a-f]{40}", base):
        raise ValueError("A full immutable base SHA is required")
    if not branch or branch.startswith("-") or any(c in branch for c in "\r\n"):
        raise ValueError("Invalid target branch")
    # Validate a literal heads ref, without Git's branch shorthand expansion.
    execute(["git", "check-ref-format", f"refs/heads/{branch}"], stdout=subprocess.DEVNULL)
    execute(["git", "-C", str(candidate), "-c", "core.hooksPath=/dev/null",
             "fetch", "--no-tags", "--", f"https://github.com/{repository}.git", f"refs/heads/{branch}"])
    current = subprocess.check_output([
        "git", "-C", str(candidate), "rev-parse", "--verify", "FETCH_HEAD^{commit}"
    ], text=True).strip()
    if current != base:
        raise ValueError("Target branch advanced after admission; update the PR branch and requeue")
    ancestry = subprocess.run(["git", "-C", str(candidate), "merge-base", "--is-ancestor", base, head])
    if ancestry.returncode == 1:
        raise ValueError("PR branch must contain the current target; rebase or merge it before testing")
    ancestry.check_returncode()


def validate(args):
    # The detached runner must not outlive its controlling Buildbot command,
    # including a forced kill or a stop before start returns the run identity.
    owner_path = Path.cwd() / "validation-owner.lock"
    with owner_path.open("a+") as owner:
        fcntl.flock(owner, fcntl.LOCK_EX | fcntl.LOCK_NB)
        owner.seek(0)
        owner.truncate()
        owner.write(str(os.getpid()))
        owner.flush()
        return validate_owned(args, owner_path)


def validate_owned(args, owner_path):
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", args.repository):
        raise ValueError("Invalid GitHub repository")
    root = Path.cwd()
    evidence = root / "evidence"
    evidence.mkdir(exist_ok=True)
    candidate, base = root / "candidate", root / "base"
    checkout(args.repository, args.head, candidate)
    base_sha = args.base or args.head
    if args.base:
        require_current_target(args.repository, candidate, base_sha, args.head, args.target_branch)
    checkout(args.repository, base_sha, base)
    nix_version = subprocess.check_output(["nix", "--version"], text=True).strip()
    print(nix_version, flush=True)
    identity = {"repository": args.repository, "head": args.head, "base": base_sha, "merge": args.head}
    identity["nixVersion"] = nix_version
    (evidence / "identity.json").write_text(json.dumps(identity, indent=2) + "\n")
    # Record producers for master too. Normal evaluation registers generated
    # source files which a fresh store's read-only flake check cannot create.
    trees = [("base", base), ("candidate", candidate)] if args.base else [("candidate", candidate)]
    for name, tree in trees:
        with (evidence / f"{name}-graph.json").open("w") as output:
            execute(["nix", "eval", "--show-trace", "--json", f"{tree}#graph"], stdout=output)
    if args.base:
        difference = json.loads(subprocess.check_output([
            sys.executable, str(Path(args.compare).resolve()),
            str(evidence / "base-graph.json"), str(evidence / "candidate-graph.json"),
            "--json", "--report-only",
        ], text=True))
        difference["informational"] = True
        difference["ciIdentity"] = identity
        (evidence / "graph-diff.json").write_text(json.dumps(difference, indent=2) + "\n")
        print("Graph comparison (informational): " + "; ".join(
            f"{len(difference[key])} {key}" for key in ("added", "changed", "removed")), flush=True)
        for key in ("added", "changed", "removed"):
            for name in difference[key]:
                print(f"  {key}: {name}", flush=True)
    execute(["nix", "flake", "check", "--show-trace", "--no-build", str(candidate)])
    start = subprocess.check_output([
        "nix", "run", "--show-trace", args.tools_ref + "#test", "--", "start", "--flake", str(candidate),
        "--system", "x86_64-linux", "--state-dir", str(root / "validation"),
        "--owner-lock", str(owner_path), "--json",
    ], text=True)
    launch = json.loads(start)
    run = Path(launch["run"])
    frozen_runner = Path(launch["runner"])
    (evidence / "launch.json").write_text(json.dumps(launch, indent=2) + "\n")
    # Never find this run via latest; another request may move that alias.
    waited = wait_for_run(frozen_runner, run)
    result = json.loads(subprocess.check_output([
        str(frozen_runner), "status", "--run", str(run), "--json"
    ], text=True))
    result["ciIdentity"] = identity
    result["workerRun"] = str(run)
    (evidence / "status.json").write_text(json.dumps(result, indent=2) + "\n")
    for name in ["nix.log", "prepare.log", "worker.log", "plan.json", "command.json"]:
        if (run / name).is_file():
            shutil.copyfile(run / name, evidence / name)
    failures = evidence / "failure-logs"
    failures.mkdir(exist_ok=True)
    for drv in result.get("reportedFailedDerivations", []):
        if not re.fullmatch(r"/nix/store/[a-z0-9]{32}-[^/\n]+\.drv", drv):
            continue
        log = subprocess.run(["nix", "log", drv], text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        if log.returncode == 0:
            (failures / (Path(drv).name + ".log")).write_text(log.stdout)
            print(f"\nFull failure log: {drv}\n{log.stdout}", flush=True)
    return result, 0 if waited.returncode == 0 and result["phase"] == "passed" else 1


def result_record(result):
    # Buildbot splits long log lines. Keep this protocol record below its line
    # limit; evidence/status.json retains the complete per-job report.
    compact = {key: result[key] for key in ("phase", "counts", "testCounts") if key in result}
    if "error" in result:
        compact["error"] = result["error"][:256]
    compact["jobs"] = {}
    for name, state in sorted(result.get("jobs", {}).items()):
        if state.get("status") != "failed-or-blocked":
            continue
        compact["jobs"][name] = {"status": "failed-or-blocked"}
        if len(json.dumps(compact)) > 3000:
            del compact["jobs"][name]
            break
    return json.dumps(compact)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", required=True)
    parser.add_argument("--head", required=True)
    parser.add_argument("--base", default="")
    parser.add_argument("--target-branch", default="master")
    parser.add_argument("--tools-ref", required=True)
    parser.add_argument("--compare", required=True)
    args = parser.parse_args()
    try:
        result, code = validate(args)
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        result, code = {"phase": "error", "error": str(error)[:500]}, 2
    evidence = Path("evidence")
    evidence.mkdir(exist_ok=True)
    if code == 2:
        (evidence / "status.json").write_text(json.dumps(result, indent=2) + "\n")
    print("TVP_CI_RESULT=" + result_record(result), flush=True)
    return code


if __name__ == "__main__":
    sys.exit(main())

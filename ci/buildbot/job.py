#!/usr/bin/env python3
"""Trusted worker harness: pinned integration tree, graph policy, frozen full suite."""
import argparse
import json
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


def validate(args):
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", args.repository):
        raise ValueError("Invalid GitHub repository")
    root = Path.cwd()
    evidence = root / "evidence"
    evidence.mkdir(exist_ok=True)
    candidate, base = root / "candidate", root / "base"
    checkout(args.repository, args.head, candidate)
    base_sha = args.base or args.head
    checkout(args.repository, base_sha, base)
    if base_sha != args.head:
        # Both histories are fetched in full: the common ancestor is needed for a real merge.
        execute(["git", "-C", str(candidate), "fetch", "--no-tags",
                 f"https://github.com/{args.repository}.git", base_sha])
        execute(["git", "-C", str(candidate), "-c", "core.hooksPath=/dev/null",
                 "-c", "user.name=TVP CI", "-c", "user.email=ci@tvp.invalid",
                 "-c", "commit.gpgSign=false", "merge", "--no-edit", base_sha])
    merge = subprocess.check_output(["git", "-C", str(candidate), "rev-parse", "HEAD"], text=True).strip()
    identity = {"repository": args.repository, "head": args.head, "base": base_sha, "merge": merge}
    (evidence / "identity.json").write_text(json.dumps(identity, indent=2) + "\n")
    if args.base:
        for name, tree in [("base", base), ("candidate", candidate)]:
            with (evidence / f"{name}-graph.json").open("w") as output:
                execute(["nix", "eval", "--json", f"{tree}#graph"], stdout=output)
        execute([sys.executable, str(Path(args.compare).resolve()),
                 str(evidence / "base-graph.json"), str(evidence / "candidate-graph.json"), "--json"]
                + [arg for name in args.allow_change for arg in ["--allow-change", name]])
    execute(["nix", "flake", "check", "--no-build", str(candidate)])
    start = subprocess.check_output([
        "nix", "run", args.tools_ref + "#test", "--", "start", "--flake", str(candidate),
        "--system", "x86_64-linux", "--state-dir", str(root / "validation"), "--json",
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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", required=True)
    parser.add_argument("--head", required=True)
    parser.add_argument("--base", default="")
    parser.add_argument("--tools-ref", required=True)
    parser.add_argument("--compare", required=True)
    parser.add_argument("--allow-change", action="append", default=[])
    args = parser.parse_args()
    try:
        result, code = validate(args)
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        result, code = {"phase": "error", "error": str(error)[:500]}, 2
    evidence = Path("evidence")
    evidence.mkdir(exist_ok=True)
    if code == 2:
        (evidence / "status.json").write_text(json.dumps(result, indent=2) + "\n")
    print("TVP_CI_RESULT=" + json.dumps(result), flush=True)
    return code


if __name__ == "__main__":
    sys.exit(main())

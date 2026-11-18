#!/usr/bin/env python3
"""Trusted worker harness: exact PR head, current target gate, frozen smoke checks."""
import argparse
from contextlib import contextmanager
from datetime import datetime, timezone
import fcntl
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time


def execute(argv, **kwargs):
    return subprocess.run(argv, check=True, **kwargs)


def note(message, **kwargs):
    stamp = datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")
    print(f"[{stamp}] {message}", flush=True, **kwargs)


@contextmanager
def timed(label):
    note(f"{label} started")
    start = time.monotonic()
    try:
        yield
    finally:
        note(f"{label} finished in {time.monotonic() - start:.1f}s")


def check_flake(candidate, evidence):
    log = evidence / "flake-check.log"
    note("Flake evaluation started (flake-evaluation log)")
    start = time.monotonic()
    try:
        with log.open("wb") as stream:
            execute(["nix", "flake", "check", "--show-trace", "--no-build", str(candidate)],
                    stdout=stream, stderr=subprocess.STDOUT)
    except subprocess.CalledProcessError:
        note(f"Flake evaluation failed after {time.monotonic() - start:.1f}s "
             "(last 40 lines of evidence/flake-check.log)", file=sys.stderr)
        with log.open("rb") as stream:
            stream.seek(0, os.SEEK_END)
            stream.seek(max(0, stream.tell() - 16000))
            tail = stream.read().decode("utf-8", errors="replace").splitlines()[-40:]
        if tail:
            print("\n".join(tail), file=sys.stderr, flush=True)
        raise
    note(f"Flake evaluation passed in {time.monotonic() - start:.1f}s")


def checkout(repository, revision, destination):
    if not re.fullmatch(r"[0-9a-f]{40}", revision):
        raise ValueError("A full immutable commit SHA is required")
    destination.mkdir(parents=True)
    execute(["git", "init", "--quiet", str(destination)])
    execute(["git", "-C", str(destination), "-c", "core.hooksPath=/dev/null",
             "fetch", "--quiet", "--no-tags", f"https://github.com/{repository}.git", revision])
    execute(["git", "-C", str(destination), "checkout", "--quiet", "--detach", revision])
    actual = subprocess.check_output(["git", "-C", str(destination), "rev-parse", "HEAD"], text=True).strip()
    if actual != revision:
        raise ValueError("Checkout does not match the scheduled commit")


def require_current_target(repository, candidate, base, head, branch):
    if not re.fullmatch(r"[0-9a-f]{40}", base):
        raise ValueError("A full immutable base SHA is required")
    if not branch or branch.startswith("-") or any(c in branch for c in "\r\n"):
        raise ValueError("Invalid target branch")
    # Validate a literal heads ref, without Git's branch shorthand expansion.
    execute(["git", "check-ref-format", f"refs/heads/{branch}"], stdout=subprocess.DEVNULL)
    execute(["git", "-C", str(candidate), "-c", "core.hooksPath=/dev/null",
             "fetch", "--quiet", "--no-tags", "--", f"https://github.com/{repository}.git", f"refs/heads/{branch}"])
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
    # including a forced kill before the foreground command returns its result.
    owner_path = Path.cwd() / "validation-owner.lock"
    with owner_path.open("a+") as owner:
        fcntl.flock(owner, fcntl.LOCK_EX | fcntl.LOCK_NB)
        owner.seek(0)
        owner.truncate()
        owner.write(str(os.getpid()))
        owner.flush()
        return validate_owned(args, owner_path)


def read_result(validation):
    run = (validation / "latest").resolve(strict=True)
    if run.parent != (validation / "runs").resolve():
        raise ValueError("CI receipt is outside this validation's runs directory")
    result = json.loads((run / "result.json").read_text())
    if not isinstance(result, dict) or result.get("run") != str(run):
        raise ValueError("CI receipt identifies a different run")
    return result


def validate_owned(args, owner_path):
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", args.repository):
        raise ValueError("Invalid GitHub repository")
    root = Path.cwd()
    evidence = root / "evidence"
    evidence.mkdir(exist_ok=True)
    candidate, base = root / "candidate", root / "base"
    base_sha = args.base or args.head
    with timed(f"Checkout {args.head[:12]} (base {base_sha[:12]})"):
        checkout(args.repository, args.head, candidate)
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
        with timed(f"{name.capitalize()} graph evaluation"), (evidence / f"{name}-graph.json").open("w") as output:
            execute(["nix", "eval", "--show-trace", "--json", f"{tree}#graph"], stdout=output)
    if args.base:
        with timed("Graph comparison"):
            difference = json.loads(subprocess.check_output([
                sys.executable, str(Path(args.compare).resolve()),
                str(evidence / "base-graph.json"), str(evidence / "candidate-graph.json"),
                "--json", "--report-only",
            ], text=True))
        difference["informational"] = True
        difference["ciIdentity"] = identity
        (evidence / "graph-diff.json").write_text(json.dumps(difference, indent=2) + "\n")
        categories = ("added", "changed", "removed")
        summary = ", ".join(f"{len(difference[key])} {key}" for key in categories)
        with (evidence / "graph-diff.log").open("w") as detail:
            print(summary, file=detail)
            for key in categories:
                for name in difference[key]:
                    print(f"{key} {name}", file=detail)
        note(f"Graph comparison: {summary} (graph-diff log)")
    check_flake(candidate, evidence)
    validation = root / "validation"
    if validation.exists() or validation.is_symlink():
        raise ValueError("CI validation needs a fresh state directory")
    with timed("Smoke runner including preparation"):
        completed = subprocess.run([
            "nix", "run", "--show-trace", args.tools_ref + "#test", "--", "all", "--smoke", "--flake", str(candidate),
            "--system", "x86_64-linux", "--state-dir", str(validation),
            "--owner-lock", str(owner_path),
        ], env={**os.environ, "TVP_CI_PROGRESS": "1"})
    # A failing test still returns a terminal receipt and retained evidence.
    # Inherit the console for live progress; consume the separate machine receipt.
    result = read_result(validation)
    run = Path(result["run"])
    launch = {key: result[key] for key in ("run", "runner", "validationScope", "full")}
    (evidence / "launch.json").write_text(json.dumps(launch, indent=2) + "\n")
    result["ciIdentity"] = identity
    result["workerRun"] = str(run)
    if result.get("validationScope") != "smoke" or result.get("full") is not False:
        raise ValueError("CI result scope differs from the requested smoke plan")
    (evidence / "status.json").write_text(json.dumps(result, indent=2) + "\n")
    for name in ["nix.log", "events.jsonl", "prepare.log", "worker.log", "plan.json", "command.json", "result.json"]:
        if (run / name).is_file():
            shutil.copyfile(run / name, evidence / name)
    failures = evidence / "failure-logs"
    failures.mkdir(exist_ok=True)
    for drv in result.get("reportedFailedDerivations", []):
        if not re.fullmatch(r"/nix/store/[a-z0-9]{32}-[^/\n]+\.drv", drv):
            continue
        log = subprocess.run(["nix", "log", drv], text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        if log.returncode == 0:
            path = failures / (Path(drv).name + ".log")
            path.write_text(log.stdout)
            note(f"Failure log saved to {path.relative_to(root)}")
    return result, 0 if completed.returncode == 0 and result["phase"] == "passed" else 1


def result_record(result):
    # Buildbot splits long log lines. Keep this protocol record below its line
    # limit; evidence/status.json retains the complete per-job report.
    compact = {key: result[key] for key in ("phase", "counts", "testCounts", "validationScope", "full") if key in result}
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

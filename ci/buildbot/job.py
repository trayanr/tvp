#!/usr/bin/env python3
"""Validate the exact PR head against its admitted target."""
import argparse
from concurrent.futures import ThreadPoolExecutor
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
from tempfile import TemporaryDirectory
import time


SYSTEM = "x86_64-linux"
SMOKE_EVALUATORS = 4


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


def build_snapshot(link, expression, *arguments):
    execute(["nix", "build", "--show-trace", "--no-write-lock-file", "--out-link", str(link),
             "--expr", expression, *arguments], stdout=sys.stderr)
    return link.resolve(strict=True)


def parallel_snapshot(scope, snapshot, workers):
    # Each evaluator roots its part before terminating. Keep those roots until
    # the assembled snapshot protects the original, complete smoke plan.
    with TemporaryDirectory(prefix="smoke-plan-", dir=snapshot.parent) as temporary:
        directory = Path(temporary)

        def evaluate(index):
            expression = scope + f"""
              builtins.toFile "tvp-ci-smoke-part.json" (builtins.toJSON (
                {{ revision = candidate.rev; inherit system;
                   entries = smoke.planPart {{ index = {index}; count = {workers}; }}; }}
                // (if {index} == 0 then {{ inherit graphJson; }} else {{}})
              ))
            """
            return build_snapshot(directory / f"part-{index}", expression)

        with ThreadPoolExecutor(max_workers=workers) as executor:
            paths = list(executor.map(evaluate, range(workers)))
        parts = [json.loads(path.read_bytes()) for path in paths]
        references = subprocess.check_output(
            ["nix-store", "--query", "--references", *map(str, paths)], text=True,
        ).splitlines()
        payload = directory / "assembly.json"
        payload.write_text(json.dumps({"graphJson": parts[0].pop("graphJson"),
                                       "parts": parts, "references": sorted(set(references))}))
        # Feed JSON as a CLI argument file to keep candidate evaluation pure.
        # The final expression recreates the reference context of the plan.
        build_snapshot(snapshot, "{ payload }: " + scope + """
          { snapshot = let
              data = builtins.fromJSON payload;
            in seal data.graphJson (smoke.joinPlan { inherit (data) parts references; });
          }
        """, "--arg-from-file", "payload", str(payload), "snapshot")


def candidate_snapshot(candidate, revision, evidence, workers=SMOKE_EVALUATORS):
    reference = f"git+{candidate.as_uri()}?rev={revision}&ref=HEAD"
    scope = f"""
      let
        candidate = builtins.getFlake {json.dumps(reference)};
        system = {json.dumps(SYSTEM)};
        smoke = candidate.smokeTestPlanParts.${{system}} or {{}};
        graph = candidate.legacyPackages.${{system}}.graph or candidate.graph;
        graphJson = builtins.unsafeDiscardStringContext (builtins.toJSON graph);
        seal = graph: plan:
          let planPath = builtins.unsafeDiscardStringContext plan;
          in builtins.toFile "tvp-ci-snapshot.json" (builtins.toJSON {{
            schema = 1;
            inherit (candidate) rev;
            graphJson = graph;
            plan = if builtins.isString plan then
              assert ((builtins.getContext plan).${{planPath}}.path or false);
              plan
            else null;
          }});
      in
    """
    snapshot = candidate.parent / "ci-snapshot"
    supported = workers > 1 and json.loads(subprocess.check_output(
        ["nix", "eval", "--json", "--show-trace", "--no-write-lock-file", "--expr",
         scope + "smoke ? planPart && smoke ? joinPlan"], text=True,
    ))
    if supported:
        note(f"Evaluating the smoke plan with {workers} Nix processes")
        parallel_snapshot(scope, snapshot, workers)
    else:
        # Older candidates expose the single plan. If it is a derivation,
        # the runner uses its regular preparation path.
        build_snapshot(snapshot, scope + f'seal graphJson candidate.smokeTestPlans.{SYSTEM}')
    result = json.loads(snapshot.read_text())
    if result.get("schema") != 1 or result.get("rev") != revision:
        raise ValueError("Candidate snapshot does not match the scheduled commit")
    (evidence / "candidate-graph.json").write_text(result["graphJson"] + "\n")
    if result["plan"] is None:
        return None
    plan = Path(result["plan"])
    if (plan.parent != Path("/nix/store") or not re.fullmatch(r"[a-z0-9]{32}-.+", plan.name)
            or plan.is_symlink() or not plan.is_file()):
        raise ValueError("Candidate snapshot contains an invalid smoke plan path")
    manifest = json.loads(plan.read_text())
    if not isinstance(manifest, dict) or (manifest.get("schema"), manifest.get("revision"), manifest.get("system")) != (
        1, revision, SYSTEM
    ):
        raise ValueError("Candidate smoke plan does not match the scheduled commit or system")
    return plan


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


def run_smoke(candidate, evidence):
    link = evidence.parent / "smoke-result"
    with timed("Smoke checks"):
        execute([
            "nix", "build", "--show-trace", "--no-write-lock-file", "--print-build-logs",
            "--out-link", str(link), f"{candidate}#smokeTests.{SYSTEM}.all",
        ])
    (evidence / "smoke.json").write_text(json.dumps({"output": str(link.resolve(strict=True))}) + "\n")


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
    catalogue = getattr(args, "catalogue", False)
    if catalogue:
        run_smoke(candidate, evidence)
    if args.base:
        with timed("Base graph evaluation"), (evidence / "base-graph.json").open("w") as output:
            execute(["nix", "eval", "--show-trace", "--json", f"{base}#graph"], stdout=output)
    # Normal evaluation registers generated source files which a fresh
    # store's read-only flake check cannot create.
    plan = None
    if catalogue:
        with timed("Candidate graph evaluation"), (evidence / "candidate-graph.json").open("w") as output:
            execute(["nix", "eval", "--show-trace", "--json", f"{candidate}#graph"], stdout=output)
    else:
        with timed("Candidate graph and smoke plan evaluation"):
            plan = candidate_snapshot(candidate, args.head, evidence)
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
    runner_env = {**os.environ, "TVP_CI_PROGRESS": "1"}
    runner_env.pop("TVP_CI_FROZEN_SMOKE_PLAN", None)
    if plan is not None:
        runner_env["TVP_CI_FROZEN_SMOKE_PLAN"] = str(plan)
    scope = "catalogue" if catalogue else "smoke"
    with timed(f"{scope.capitalize()} runner including preparation"):
        completed = subprocess.run([
            "nix", "run", "--show-trace", args.tools_ref + "#test", "--", "all", f"--{scope}", "--flake", str(candidate),
            "--system", SYSTEM, "--state-dir", str(validation),
            "--owner-lock", str(owner_path),
        ], env=runner_env)
    # A failing test still returns a terminal receipt and retained evidence.
    # Inherit the console for live progress; consume the separate machine receipt.
    result = read_result(validation)
    run = Path(result["run"])
    launch = {key: result[key] for key in ("run", "runner", "validationScope", "full")}
    (evidence / "launch.json").write_text(json.dumps(launch, indent=2) + "\n")
    result["ciIdentity"] = identity
    result["workerRun"] = str(run)
    if result.get("validationScope") != scope or result.get("full") is not catalogue:
        raise ValueError(f"CI result scope differs from the requested {scope} plan")
    if catalogue:
        manifest = json.loads((run / "plan.json").read_text())
        if (manifest.get("revision"), manifest.get("system"), manifest.get("validationScope")) != (
            args.head, SYSTEM, scope
        ):
            raise ValueError("Catalogue manifest differs from the scheduled commit, system or scope")
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
    parser.add_argument("--catalogue", action="store_true")
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

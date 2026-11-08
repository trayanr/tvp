"""One latest-only workflow: freeze, prepare, supervise, verify and retain."""

import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

from latest_graph import Store, graph, identities, preparation, retain, verify_outputs
from latest_supervisor import (TERMINAL, environment, held, interfaces, launch, load,
                               save, snapshot, stop)
from verifier import digest, require

FILES = ("latest.py", "latest_worker.py", "latest_graph.py", "latest_supervisor.py",
         "latest-plan.nix", "native_graph.py", "verifier.py", "graph_compare.py")


def query(command, **kwargs):
    return json.loads(subprocess.check_output(command, text=True, timeout=180, **kwargs))


def freeze(run, flake, system, foreground):
    host = interfaces(foreground)
    host["bin"] = str(run / "bin")
    host["python"] = str(Path(sys.executable).resolve())
    (run / "bin").mkdir()
    for name in ("nix", "nix-store"):
        (run / "bin" / name).symlink_to(host["binaries"][name])
    save(run / "host.json", host)
    env = environment(host)
    metadata = query(["nix", "flake", "metadata", "--json", "--no-write-lock-file", flake], env=env)
    source = metadata["path"]
    require(isinstance(source, str) and source.startswith("/nix/store/"), "Immutable source required")
    revision = metadata.get("revision", metadata.get("locked", {}).get("rev"))
    tree = None
    local = Path(flake)
    if local.is_dir() and (local / "flake.nix").exists():
        # A clean committed input gives head/tree in addition to Nix's snapshot.
        require(subprocess.check_output(["git", "-C", str(local), "status", "--porcelain"], text=True).strip() == "",
                "Commit local source before starting latest workflow")
        head = subprocess.check_output(["git", "-C", str(local), "rev-parse", "HEAD"], text=True).strip()
        require(head == revision, "Snapshot revision differs from local HEAD")
        tree = subprocess.check_output(["git", "-C", str(local), "rev-parse", "HEAD^{tree}"], text=True).strip()
    (run / "code").mkdir()
    for file in FILES:
        shutil.copyfile(Path(__file__).with_name(file), run / "code" / file)
    d = query(["nix", "eval", "--impure", "--json", "--no-write-lock-file", "--option",
               "allow-import-from-derivation", "false", "--file", str(run / "code/latest-plan.nix"),
               "--apply", 'plan: plan { flake = builtins.getEnv "TVP_LATEST_FLAKE"; system = builtins.getEnv "TVP_LATEST_SYSTEM"; }'],
              env=dict(env, TVP_LATEST_FLAKE="path:" + source, TVP_LATEST_SYSTEM=system))
    require(d["source"] == source and d["system"] == system, "Frozen descriptor subject differs")
    save(run / "descriptor.json", d)
    document = query(["nix", "derivation", "show", "--offline", "--recursive", "--stdin"],
                     input=d["aggregate"]["drv"] + "\n", env=env)
    nodes = graph(document)
    expected = identities(d, nodes)
    known = {o["path"] for n in nodes.values() for o in n["outputs"].values() if "path" in o}
    valid = Store().valid(known)
    requests = preparation(d, nodes, valid)
    save(run / "graph.json", nodes)
    save(run / "preflight.json", {"schema": "tvp.latest-preflight/v1", "graphNodes": len(nodes),
                                  "graphOutputs": len(known), "selectedOutputs": len(expected),
                                  "valid": sorted(valid), "heavyRequests": requests,
                                  "requiredMissing": sorted(expected - valid)})
    subject = {"flake": flake, "source": source, "revision": revision, "tree": tree, "system": system,
               "snapshot": metadata, "descriptorSHA256": digest(run / "descriptor.json")}
    save(run / "subject.json", subject)
    # Protect source, recipes, interpreter and exact host interfaces. Code is also
    # copied and sealed so a checkout edit cannot alter an active worker.
    roots = {source, d["recipeManifest"]}
    for executable in [sys.executable, *host["binaries"].values()]:
        resolved = Path(executable).resolve()
        require(str(resolved).startswith("/nix/store/"), "Host interface must be store-backed: " + str(resolved))
        roots.add("/nix/store/" + resolved.parts[3])
    save(run / "runtime-roots.json", retain(run, roots))
    bindings = {p: digest(run / p) for p in (
        "descriptor.json", "graph.json", "subject.json", "host.json", *("code/" + file for file in FILES))}
    save(run / "bindings.json", bindings)
    return subject


def can_retry(run, state):
    require(not (run / "stop.json").exists() and state["phase"] != "stopped", "User-stopped work cannot resume")
    require(state["phase"] == "interrupted", "Only infrastructure interruption permits a retry; compiler/test/error outcomes do not")
    require(not state["workerActive"], "Worker is still healthy; reconnect without retry")
    require(state["attempt"] < 2, "Maximum two unchanged attempts; no third run")
    for file, sha in load(run / "bindings.json").items():
        require(digest(run / file) == sha, "Frozen source/code/command identity differs: " + file)


def start(args):
    run = (args.resume or args.state_dir).absolute().resolve()
    if args.resume:
        require((run / "subject.json").exists(), "No frozen run to resume")
    else:
        run.mkdir(parents=True, exist_ok=True)
    with (run / "launch.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        if args.resume:
            subject = load(run / "subject.json")
            require(args.flake is None or args.flake == subject["flake"], "Resume source argument differs; frozen source is authoritative")
            require(args.system is None or args.system == subject["system"], "Resume system differs")
            state = snapshot(run)
            require(args.expect_source is None or args.expect_source == subject["source"], "Expected source differs")
            if state["workerActive"] or state["phase"] == "passed":
                print(json.dumps(state))
                return 0
            if not args.retry_interrupted:
                print(json.dumps(state))
                return int(state["phase"] != "passed")
            can_retry(run, state)
            # Preserve an honest lost-worker observation, without overwriting an
            # original worker receipt. The next attempt uses the same snapshot.
            save(run / "attempts" / f"{state['attempt']:03}" / "resume-observation.json", state)
            state = {k: state[k] for k in ("schema", "full", "source", "revision", "tree", "system",
                                           "deadlineSeconds", "cachedOnly", "startedAt", "attempt")}
            state["attempt"] += 1
            foreground = load(run / "host.json")["foreground"]
        else:
            require(not (run / "state.json").exists() and not (run / "descriptor.json").exists(),
                    "State directory already belongs to a run; use --resume PATH")
            (run / "roots").mkdir(exist_ok=True)
            state = {"schema": "tvp.latest-state/v1", "phase": "freezing", "full": False,
                     "startedAt": time.time(), "attempt": 1, "deadlineSeconds": args.deadline,
                     "cachedOnly": args.cached_only}
            save(run / "state.json", state)
            try:
                subject = freeze(run, args.flake or ".", args.system or os.environ.get("TVP_TEST_SYSTEM", "x86_64-linux"), args.foreground)
                state.update({k: subject[k] for k in ("source", "revision", "tree", "system")})
                require(args.expect_source is None or args.expect_source == subject["source"], "Expected source differs")
                preflight = load(run / "preflight.json")
                require(not args.cached_only or not preflight["requiredMissing"] and not preflight["heavyRequests"],
                        "--cached-only preflight refused missing selected outputs/heavy work")
            except Exception as error:
                state.update(phase="error", error=str(error), terminal=True, finishedAt=time.time(),
                             machineReady=False, mergeEligible=False)
                save(run / "state.json", state)
                save(run / "result.json", state)
                raise
            foreground = args.foreground
            config = load(run / "host.json")
            config["foreground"] = foreground
            save(run / "host.json", config)
            bindings = load(run / "bindings.json")
            bindings["host.json"] = digest(run / "host.json")
            save(run / "bindings.json", bindings)
        state.update(phase="launching", terminal=False)
        save(run / "state.json", state)
        attempt = run / "attempts" / f"{state['attempt']:03}"
        attempt.mkdir(parents=True)
        config = load(run / "host.json")
        child = launch(run, attempt, config, foreground, state["deadlineSeconds"], config["python"])
    if foreground:
        return child.wait()
    print(json.dumps({"schema": "tvp.latest-launch/v1", "run": str(run), "attempt": state["attempt"],
                      "subject": subject, "full": False, "observerBound": False}))
    return 0


def verify(run):
    state = snapshot(run)
    require(state["phase"] == "passed" and not state["workerActive"], "Terminal successful worker required")
    for file, sha in load(run / "bindings.json").items():
        require(digest(run / file) == sha, "Frozen input differs: " + file)
    receipt = load(run / "state.json")
    require(receipt.get("terminal") is True and receipt.get("workerReturnCode") == 0
            and receipt.get("full") is False and receipt.get("currentChild") is None
            and not receipt.get("error"), "Invalid terminal worker receipt")
    subject = load(run / "subject.json")
    require(all(receipt.get(k) == subject[k] for k in ("source", "revision", "tree", "system")),
            "Terminal source binding differs")
    attempt = run / "attempts" / f"{receipt['attempt']:03}"
    command_path = Path(receipt["commandRecord"])
    require(command_path.parent == attempt, "Unowned terminal command receipt")
    command = load(command_path)
    require(command.get("phase") == "aggregate" and command.get("terminal") is True
            and command.get("returnCode") == 0
            and command.get("targets") == [load(run / "descriptor.json")["aggregate"]["drv"] + "^*"],
            "Invalid terminal aggregate/client receipt")
    return {"schema": "tvp.latest-verification/v1", "full": False,
            "subject": load(run / "subject.json"), "result": "PASS",
            "coverage": verify_outputs(load(run / "descriptor.json"), load(run / "graph.json")),
            "machineReady": False, "mergeEligible": False}


def wait(run):
    before, printed = None, 0
    while True:
        state = snapshot(run)
        key = (state["phase"], state.get("commandRecord"), state.get("error"))
        if key != before or time.monotonic() - printed >= 60:
            print(json.dumps(state), flush=True)
            before, printed = key, time.monotonic()
        if state["phase"] in TERMINAL and not state["workerActive"]:
            return int(state["phase"] != "passed")
        time.sleep(1)


def main(argv=None):
    argv = list(sys.argv[1:] if argv is None else argv)
    if argv and argv[0] == "_worker":
        from latest_worker import Worker
        return Worker(Path(argv[1]), Path(argv[2])).execute()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", nargs="?", choices=("start", "status", "wait", "stop", "verify"), default="start")
    parser.add_argument("--flake", help="flake to snapshot once; resume never follows branch movement")
    parser.add_argument("--system")
    parser.add_argument("--state-dir", type=Path, default=Path(".tvp-latest"))
    parser.add_argument("--resume", type=Path, help="reconnect to this exact frozen run")
    parser.add_argument("--run", type=Path, help="exact run for status/wait/stop/verify")
    parser.add_argument("--expect-source")
    parser.add_argument("--retry-interrupted", action="store_true", help="explicit one-time infrastructure retry")
    parser.add_argument("--foreground", action="store_true", help="explicit non-durable foreground backend")
    parser.add_argument("--cached-only", action="store_true", help="refuse any missing selected output, including aggregate")
    parser.add_argument("--deadline", type=int, default=28800, help="finite worker deadline in seconds (60..604800)")
    parser.add_argument("--json", action="store_true", help="all latest responses are JSON")
    args = parser.parse_args(argv)
    try:
        require(60 <= args.deadline <= 604800, "Deadline must be 60..604800 seconds")
        require(not args.retry_interrupted or args.resume, "Retry requires --resume")
        if args.action == "start":
            return start(args)
        run = (args.run or args.resume or args.state_dir).resolve()
        if args.action == "wait":
            return wait(run)
        if args.action == "stop":
            stop(run)
            print(json.dumps({"run": str(run), "stopRequested": True}))
        elif args.action == "verify":
            print(json.dumps(verify(run)))
        else:
            print(json.dumps(snapshot(run)))
        return 0
    except (OSError, ValueError, RuntimeError, KeyError, subprocess.SubprocessError) as error:
        print(json.dumps({"schema": "tvp.latest-error/v1", "error": str(error), "full": False}), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())

"""Signal-aware finite worker; observers never own its lifetime."""

import fcntl
import os
from pathlib import Path
import signal
import subprocess
import time

from latest_graph import Store, identities, preparation, retain, verify_outputs
from latest_supervisor import load, process, save
from verifier import digest, require


class Worker:
    def __init__(self, run, attempt):
        self.run, self.attempt = run, attempt
        self.child = None
        self.signals = []
        self.state = load(run / "state.json")
        self.sequence = 0

    def checkpoint(self, phase, **fields):
        self.state.update(phase=phase, updatedAt=time.time(), **fields)
        save(self.run / "state.json", self.state)

    def stopped(self):
        if (self.run / "stop.json").exists() or self.signals:
            raise InterruptedError("Explicit stop or worker signal")

    def signal(self, sig, _frame):
        self.signals.append({"signal": sig, "at": time.time()})
        if self.child and self.child.poll() is None:
            try:
                os.killpg(self.child.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass

    def command(self, phase, targets):
        self.stopped()
        command = ["nix", "build", "--no-link", "--json", "-L", "--option", "keep-going", "false", *targets]
        self.sequence += 1
        prefix = self.attempt / f"{self.sequence:03}-{phase}"
        record = {"schema": "tvp.latest-command/v1", "command": command, "startedAt": time.time(),
                  "phase": phase, "targets": targets, "returnCode": None}
        save(prefix.with_suffix(".json"), record)
        self.checkpoint(phase, commandRecord=str(prefix.with_suffix(".json")), command=command)
        try:
            with prefix.with_suffix(".log").open("w") as log:
                self.child = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
                record["client"] = process(self.child.pid)
                save(prefix.with_suffix(".json"), record)
                while self.child.poll() is None:
                    try:
                        self.child.wait(timeout=1)
                    except subprocess.TimeoutExpired:
                        self.state["heartbeatAt"] = time.time()
                        save(self.run / "state.json", self.state)
                        if self.signals or (self.run / "stop.json").exists():
                            self.signal(signal.SIGTERM, None)
                            try:
                                self.child.wait(timeout=20)
                            except subprocess.TimeoutExpired:
                                os.killpg(self.child.pid, signal.SIGKILL)
                                self.child.wait(timeout=5)
                record["returnCode"] = self.child.wait()
        finally:
            if self.child is not None and self.child.poll() is None:
                os.killpg(self.child.pid, signal.SIGKILL)
                self.child.wait(timeout=5)
            record.update(returnCode=self.child.returncode if self.child else None,
                          endedAt=time.time(), terminal=True, signals=self.signals[:])
            save(prefix.with_suffix(".json"), record)
            self.child = None
        self.stopped()
        if record["returnCode"]:
            if record["returnCode"] < 0:
                raise InterruptedError("Nix client terminated by signal")
            raise ChildProcessError(f"Build/test failed: {phase}; {prefix}.log (unknown failing dependency unless logged)")

    def execute(self):
        with (self.run / "worker.lock").open("a") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            previous = {}
            for sig in (signal.SIGTERM, signal.SIGINT, signal.SIGALRM):
                previous[sig] = signal.signal(sig, self.signal)
            signal.alarm(self.state["deadlineSeconds"] - 5)
            self.state.update(worker=process(os.getpid()), invocationID=os.environ.get("INVOCATION_ID"),
                              workerStartedAt=time.time(), full=False)
            outcome, error, coverage = "error", None, None
            try:
                self.checkpoint("preflight")
                for p, sha in load(self.run / "bindings.json").items():
                    require(digest(self.run / p) == sha, "Frozen input changed: " + p)
                d, nodes = load(self.run / "descriptor.json"), load(self.run / "graph.json")
                expected = identities(d, nodes)
                store = Store()
                # One batched query covers all known selected-graph output paths.
                paths = {o["path"] for node in nodes.values() for o in node["outputs"].values() if "path" in o}
                valid = store.valid(paths)
                requests = preparation(d, nodes, valid)
                before = {"valid": sorted(valid), "missing": sorted(paths - valid), "heavyRequests": requests,
                          "requiredValid": sorted(expected & valid), "requiredMissing": sorted(expected - valid)}
                save(self.attempt / "before.json", before)
                require(not self.state["cachedOnly"] or expected <= valid and not requests,
                        "--cached-only requires every selected output and aggregate valid; no application builds allowed")
                self.stopped()
                # Successful partial outputs remain protected even if a later stage fails.
                save(self.attempt / "roots-before.json", retain(self.run, expected & valid))
                for request in requests:
                    self.stopped()
                    outputs = set(request["outputs"].values())
                    current = store.valid(outputs)
                    save(self.attempt / ("heavy-" + Path(request["drv"]).name + ".json"),
                         dict(request, beforeValid=sorted(current)))
                    if outputs <= current:
                        continue
                    self.command("heavy", [request["drv"] + "^" + ",".join(sorted(request["outputs"]))])
                    require(store.valid(outputs) == outputs, "Heavy request missing demanded outputs: " + request["drv"])
                    retain(self.run, outputs)
                # Recheck the heavy gate. No latest aggregate can race preparation.
                heavy_outputs = {p for request in requests for p in request["outputs"].values()}
                require(store.valid(heavy_outputs) == heavy_outputs, "Heavy gate lost prepared outputs")
                self.command("aggregate", [d["aggregate"]["drv"] + "^*"])
                self.checkpoint("verify")
                coverage = verify_outputs(d, nodes, store)
                self.checkpoint("retain")
                roots = retain(self.run, expected)
                save(self.attempt / "roots.json", {"owner": "tvp-test latest", "lifecycle": "run-owned; no automatic deletion", "roots": roots})
                self.stopped()
                outcome = "passed"
            except InterruptedError as exc:
                outcome = "stopped" if (self.run / "stop.json").exists() else "interrupted"
                error = str(exc)
            except ChildProcessError as exc:
                outcome, error = "failed", str(exc)
            except Exception as exc:
                error = f"{type(exc).__name__}: {exc}"
            finally:
                signal.alarm(0)
                # Root only exact currently valid selected successes after failures too.
                if outcome != "passed":
                    try:
                        d = load(self.run / "descriptor.json")
                        paths = set(d["requiredOutputs"]) | {d["aggregate"]["out"]}
                        save(self.attempt / "partial-roots.json", retain(self.run, Store().valid(paths)))
                    except Exception as exc:
                        self.state["partialRetentionError"] = str(exc)
                receipt = dict(self.state, schema="tvp.latest-result/v1", phase=outcome, terminal=True,
                               failedStage=self.state["phase"] if outcome != "passed" else None,
                               error=error, coverage=coverage, signals=self.signals, finishedAt=time.time(),
                               workerReturnCode=0 if outcome == "passed" else 1, currentChild=None,
                               machineReady=False, mergeEligible=False, freshExecutionCertified=False)
                save(self.attempt / "result.json", receipt)
                save(self.run / "state.json", receipt)
                save(self.run / "result.json", receipt)
                for sig, handler in previous.items():
                    signal.signal(sig, handler)
        return 0 if outcome == "passed" else 1

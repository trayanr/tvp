"""Finite Linux user-systemd supervision and PID-reuse-safe process identity."""

import fcntl
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import time

from verifier import require

TERMINAL = {"passed", "failed", "error", "interrupted", "stopped"}


def save(path, value):
    temporary = path.with_name(path.name + f".{os.getpid()}.tmp")
    with temporary.open("w") as stream:
        json.dump(value, stream, indent=2, sort_keys=True)
        stream.write("\n")
        stream.flush()
        os.fsync(stream.fileno())
    os.replace(temporary, path)


def load(path):
    return json.loads(path.read_text())


def process(pid):
    try:
        proc = Path("/proc") / str(pid)
        stat = (proc / "stat").read_text().rsplit(")", 1)[1].split()
        return {"pid": pid, "startTicks": stat[19], "cgroup": (proc / "cgroup").read_text(),
                "bootID": Path("/proc/sys/kernel/random/boot_id").read_text().strip()}
    except FileNotFoundError:
        return None


def same_process(identity):
    return bool(identity) and process(identity["pid"]) == identity


def held(path):
    if not path.exists():
        return False
    with path.open("rb") as stream:
        try:
            fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return True
    return False


def interfaces(foreground=False):
    binaries = {}
    for name in ("nix", "nix-store") + (() if foreground else ("systemd-run", "systemctl")):
        found = shutil.which(name)
        require(found is not None, "Required host interface unavailable: " + name)
        binaries[name] = str(Path(found).resolve())
    env = dict(os.environ)
    if not foreground:
        runtime = env.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
        env.update(XDG_RUNTIME_DIR=runtime,
                   DBUS_SESSION_BUS_ADDRESS=env.get("DBUS_SESSION_BUS_ADDRESS", "unix:path=" + runtime + "/bus"))
        result = subprocess.run([binaries["systemctl"], "--user", "show-environment"],
                                env=env, text=True, capture_output=True, timeout=20)
        require(result.returncode == 0, "Durable user systemd unavailable; configure the user bus or explicitly use --foreground: " + result.stderr)
    return {"binaries": binaries, "environment": {k: env[k] for k in (
        "PATH", "XDG_RUNTIME_DIR", "DBUS_SESSION_BUS_ADDRESS", "NIX_CONFIG", "NIX_CONF_DIR",
        "NIX_USER_CONF_FILES", "NIX_REMOTE", "HOME", "USER", "SSL_CERT_FILE", "NIX_SSL_CERT_FILE") if k in env}}


def environment(config):
    # Private shims freeze exact host Nix entrypoint spelling (nix-store is
    # commonly a symlink to nix). Other host interfaces are invoked absolutely.
    return dict(config["environment"], PATH=str(Path(config["bin"])) + ":" + config["environment"].get("PATH", ""),
                PYTHONDONTWRITEBYTECODE="1")


def unit_show(config, unit):
    result = subprocess.run([config["binaries"]["systemctl"], "--user", "show", unit, "--no-pager",
                             "--property=Id,LoadState,InvocationID,ControlGroup,MainPID,ActiveState,SubState,Result,Restart,RuntimeMaxUSec,ExecMainPID,ExecMainCode,ExecMainStatus"],
                            env=environment(config), capture_output=True, text=True, timeout=20)
    properties = dict(line.split("=", 1) for line in result.stdout.splitlines() if "=" in line)
    require(result.returncode == 0 or result.returncode == 4 and properties.get("LoadState") == "not-found",
            "Cannot inspect owned unit: " + result.stderr)
    return properties


def unit_live(config, launch):
    properties = unit_show(config, launch["unit"])
    require(properties.get("Id") == launch["unit"], "Unit identity differs")
    if launch.get("invocationID") and properties.get("LoadState") != "not-found":
        require(properties.get("InvocationID") == launch["invocationID"], "Unit invocation differs")
    return properties.get("ActiveState") in {"activating", "active", "deactivating"}, properties


def unit_name(run, attempt):
    import hashlib
    return f"tvp-latest-{hashlib.sha256(str(run).encode()).hexdigest()[:20]}-{attempt.name}.service"


def launch(run, attempt, config, foreground, deadline, executable):
    unit = unit_name(run, attempt)
    command = [executable, "-B", str(run / "code" / "latest.py"), "_worker", str(run), str(attempt)]
    record = {"unit": None if foreground else unit, "backend": "foreground" if foreground else "systemd-user",
              "deadlineSeconds": deadline, "restart": "no", "command": command, "at": time.time()}
    save(attempt / "launch.json", record)  # Intent precedes launch; never blind-relaunch an ambiguous intent.
    if foreground:
        child = subprocess.Popen(command, env=environment(config))
        record["client"] = process(child.pid)
        save(attempt / "launch.json", record)
        return child
    else:
        args = [config["binaries"]["systemd-run"], "--user", "--unit=" + unit,
                "--service-type=exec", "--property=Restart=no", f"--property=RuntimeMaxSec={deadline}",
                "--property=TimeoutStopSec=30s", "--property=KillMode=control-group",
                "--property=StandardOutput=append:" + str(attempt / "worker.log"),
                "--property=StandardError=append:" + str(attempt / "worker.log"),
                "--working-directory=" + str(run)]
        args.extend("--setenv=" + k + "=" + v for k, v in environment(config).items())
        result = subprocess.run(args + command, env=environment(config), capture_output=True, text=True, timeout=30)
        record.update(launcherReturnCode=result.returncode, launcherStderr=result.stderr)
        save(attempt / "launch.json", record)
        require(result.returncode == 0, "systemd launch failed (inspect launch.json; no automatic relaunch): " + result.stderr)
        props = unit_show(config, unit)
        record.update(invocationID=props.get("InvocationID"), properties={k: props.get(k) for k in (
            "Id", "InvocationID", "MainPID", "ControlGroup", "Restart", "RuntimeMaxUSec", "ActiveState", "Result")})
        save(attempt / "launch.json", record)
        code = 0
    return code


def snapshot(run):
    config = load(run / "host.json")
    state = load(run / "state.json")
    attempt = run / "attempts" / f"{state['attempt']:03}"
    launch_record = load(attempt / "launch.json") if (attempt / "launch.json").exists() else None
    active = held(run / "worker.lock")
    if launch_record and launch_record["backend"] == "foreground":
        active = active or same_process(launch_record.get("client"))
    props = None
    if launch_record and launch_record["unit"]:
        require(launch_record["unit"] == unit_name(run, attempt), "Unowned unit name")
        if not launch_record.get("invocationID") and state.get("invocationID"):
            launch_record = dict(launch_record, invocationID=state["invocationID"])
        live, props = unit_live(config, launch_record)
        active = active or live
    if state["phase"] not in TERMINAL and not active:
        stopped = (run / "stop.json").exists()
        state = dict(state, phase="stopped" if stopped else "interrupted",
                     reason="User stop before receipt" if stopped else "No healthy worker or active owned unit; infrastructure interruption")
    state.update(run=str(run), workerActive=active, unitObservation=props)
    return state


def stop(run):
    # Serialize with launch/resume. The stop marker is durable even if a worker
    # has not yet published a PID. It is never removed automatically.
    with (run / "launch.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        state = snapshot(run)
        require(state["phase"] not in TERMINAL or state["workerActive"], "Run is already terminal")
        save(run / "stop.json", {"reason": "explicit user stop", "at": time.time()})
        attempt = run / "attempts" / f"{state['attempt']:03}"
        record = load(attempt / "launch.json")
        config = load(run / "host.json")
        if record["unit"]:
            require(record["unit"] == unit_name(run, attempt), "Unowned unit name")
            invocation = record.get("invocationID") or state.get("invocationID")
            require(invocation, "No bound systemd invocation; refuse an ambiguous stop")
            live, props = unit_live(config, dict(record, invocationID=invocation))
            require(props.get("ControlGroup", "").endswith("/" + record["unit"]), "Unowned cgroup")
            if live:
                subprocess.run([config["binaries"]["systemctl"], "--user", "stop", record["unit"]],
                               env=environment(config), check=True, timeout=45)
        else:
            identity = state.get("worker") or record.get("client")
            require(same_process(identity), "Worker PID identity no longer matches")
            # pidfd prevents reuse between validation and signal delivery.
            fd = os.pidfd_open(identity["pid"])
            try:
                require(same_process(identity), "Worker PID reused")
                signal.pidfd_send_signal(fd, signal.SIGTERM)
            finally:
                os.close(fd)

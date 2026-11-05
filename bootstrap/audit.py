"""Observer-only audit; Python/Nix CLI are never bootstrap derivation inputs."""
import base64
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parent
STORE = "/nix/store/"


def hash_forms(sri):
    data = base64.b64decode(sri.split("-", 1)[1])
    alphabet = "0123456789abcdfghijklmnpqrsvwxyz"
    number = int.from_bytes(data, "little")
    nix32 = "".join(alphabet[(number >> shift) & 31]
                    for shift in reversed(range(0, len(data) * 8, 5)))
    return (sri, data.hex(), nix32)


def executable_root(value):
    if (not isinstance(value, str) or str(PurePosixPath(value)) != value
            or ".." in PurePosixPath(value).parts):
        return None
    match = re.match(r"/nix/store/[0-9abcdfghijklmnpqrsvwxyz]{32}-[^/\s]+", value)
    return match[0] if match else None


def nix_json(*args):
    return json.loads(subprocess.check_output(["nix", *args], text=True))


def store_path(value):
    return STORE + value if not value.startswith(STORE) else value


def audit_graph(raw, sources, provenance, stage0_pins):
    # Accept both Nix's v4 graph envelope and the older direct attrset.
    graph = {store_path(k): v for k, v in raw.get("derivations", raw).items()}
    outputs = {store_path(output.get("path", node["env"][name])): drv
               for drv, node in graph.items()
               for name, output in node["outputs"].items()}
    pins = {pin["url"]: pin["hash"] for pin in provenance["archives"]}
    pins[provenance["seed"]["url"]] = provenance["seed"]["narHash"]
    failures, nodes, source_data = [], {}, {}
    for drv, node in graph.items():
        env = node["env"]
        inputs = node.get("inputs", {})
        dependencies = [store_path(p) for p in inputs.get("drvs", node.get("inputDrvs", {}))]
        builder = node["builder"]
        path = env.get("PATH")
        if builder == "builtin:fetchurl":
            url = env.get("url")
            expected = pins.get(url)
            # Nix serializes outputHash as hexadecimal or SRI depending on version.
            actual = env.get("outputHash", "")
            if not expected or actual not in hash_forms(expected):
                failures.append(f"unrecognized download/hash: {drv}")
            origin = "explicit-seed" if url == provenance["seed"]["url"] else "pinned-source-archive"
            if (env.get("executable") == "1") != (origin == "explicit-seed"):
                failures.append(f"unexpected executable download: {drv}")
        else:
            origin = "source-built-stage"
            root = executable_root(builder)
            producer = outputs.get(root) if root else None
            if not producer or producer not in dependencies:
                failures.append(f"undeclared executable builder: {drv}: {builder}")
            if path is None:
                failures.append(f"missing explicit PATH: {drv}")
            for entry in (path or "").split(":"):
                if entry and (not entry.endswith("/bin") or outputs.get(entry[:-4]) not in dependencies):
                    failures.append(f"unclassified PATH executable input: {drv}: {entry}")
            for key in ("SHELL", "CONFIG_SHELL", "MAKESHELL"):
                if key in env and outputs.get(executable_root(env[key])) not in dependencies:
                    failures.append(f"undeclared shell interpreter: {drv}: {key}={env[key]}")
            if env.get("allowSubstitutes") != "":
                failures.append(f"source stage permits substitution: {drv}")
        nodes[drv] = {"origin": origin, "builder": builder, "PATH": path,
                      "previousStages": dependencies,
                      "outputs": {name: dict(output, path=output.get("path", env[name]))
                                  for name, output in node["outputs"].items()}}
        for src in inputs.get("srcs", node.get("inputSrcs", [])):
            src = store_path(src)
            if src in sources.values():
                kind = "pinned-stage0-source-tree"
            else:
                kind = "owned-source-or-nix-generated-text"
                if not Path(src).is_file():
                    failures.append(f"unknown source directory: {src}")
                    continue
            paths = Path(src).rglob("*") if Path(src).is_dir() else [Path(src)]
            for p in paths:
                if p.is_file():
                    data = p.read_bytes()
                    if data.startswith((b"\x7fELF", b"MZ")):
                        failures.append(f"native executable in source data: {p}")
            source_data[src] = {"origin": kind}
            if Path(src).is_file():
                source_data[src]["sha256"] = hashlib.sha256(Path(src).read_bytes()).hexdigest()
    return {"schema": 1, "boundary": ["host Nix evaluator/downloader/daemon", "x86_64 Linux kernel"],
            "nodes": nodes, "sourceData": source_data,
            "constructionPins": provenance,
            "stage0Pins": stage0_pins,
            "failures": sorted(set(failures)),
            "limits": "Classifies executable origins/edges, not compiler correctness or a trust proof."}


def audit():
    raw = nix_json("derivation", "show", "--recursive", "--file", str(ROOT),
                   "tests.consumer", "tests.versions", "tests.cxx", "tests.tools", "tests.transitions", "tests.libc", "tests.stage-comparison")
    sources = nix_json("eval", "--json", "--impure", "--expr",
                       f'let b = import {ROOT} {{}}; in builtins.mapAttrs (_: p: toString p) b.sources')
    return audit_graph(raw, sources,
                       json.loads((ROOT / "provenance.json").read_text()),
                       json.loads((ROOT / "stage0-sources.json").read_text()))


if __name__ == "__main__":
    result = audit()
    print(json.dumps(result, indent=2, sort_keys=True))
    sys.exit(bool(result["failures"]))

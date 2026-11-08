"""Latest-only native graph protocol, demand gating and exact output proofs."""

import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

from native_graph import normalize, path
from verifier import Store as NativeStore, require


class Store(NativeStore):
    def valid(self, paths):
        paths = set(paths)
        if not paths:
            return set()
        # --print-invalid makes missing paths normal stdout with a successful
        # status on host Nix (unlike a plain --check-validity failure).
        result = subprocess.run(["nix-store", "--check-validity", "--print-invalid", "--stdin"],
                                input="\n".join(sorted(paths)) + "\n", text=True,
                                capture_output=True, timeout=120)
        invalid = set(result.stdout.splitlines())
        require(result.returncode == 0 and invalid <= paths,
                "Store validity query failed or malformed: " + result.stderr)
        return paths - invalid

    def fixed_output(self, drv, node):
        require(len(node["outputs"]) == 1 and all(isinstance(o.get("hash"), str) and o["hash"]
                for o in node["outputs"].values()), "Unsupported unresolved output: " + drv)
        command = ["nix-store", "--query", "--outputs", drv]
        result = subprocess.run(command, capture_output=True, text=True, timeout=30)
        rows = result.stdout.splitlines()
        require(result.returncode == 0 and len(rows) == 1 and rows[0].startswith("/nix/store/"),
                "Fixed-output path query failed or malformed: " + drv + ": " + result.stderr)
        return {"drv": drv, "output": next(iter(node["outputs"])), "path": path(rows[0]),
                "evidence": "read-only nix-store --query --outputs", "command": command}


HEAVY = {"gcc", "gcc-cxx", "g++", "xgcc", "llvm", "clang", "jdk", "openjdk", "node", "nodejs",
         "dart", "dart-bootstrap", "flutter", "jdk-bootstrap", "gcc-bootstrap", "llvm-bootstrap",
         "clang-unwrapped", "llvm-unwrapped", "nodejs-minimal"}


def graph(document):
    # Reuse the strict native v4 parser. Old Nix's unversioned absolute-path
    # schema is adapted explicitly; unknown versioned schemas fail closed.
    if "version" not in document:
        rows = {}
        for drv, raw in document.items():
            require(isinstance(raw, dict), "Malformed legacy derivation")
            rows[drv] = dict(raw, inputs={
                "srcs": raw.get("inputSrcs", []),
                "drvs": {k: {"outputs": v, "dynamicOutputs": {}}
                         for k, v in raw.get("inputDrvs", {}).items()}})
        document = {"version": 4, "derivations": rows}
    nodes = normalize(document)
    raw = {path(k, drv=True): v for k, v in document["derivations"].items()}
    for drv, node in nodes.items():
        env = raw[drv].get("env", {})
        require(isinstance(env, dict), "Malformed derivation environment: " + drv)
        attrs = raw[drv].get("structuredAttrs")
        if attrs is None:
            require("__json" not in env or isinstance(env["__json"], str),
                    "Malformed encoded structured attributes: " + drv)
            attrs = json.loads(env["__json"]) if "__json" in env else {}
        require(isinstance(attrs, dict), "Malformed structured attributes: " + drv)
        name = env.get("name", raw[drv].get("name", attrs.get("name")))
        pname = env.get("pname", attrs.get("pname"))
        version = env.get("version", attrs.get("version"))
        require(all(value is None or isinstance(value, str) for value in (name, pname, version)),
                "Malformed application metadata: " + drv)
        # Metadata and exact application name exclude tests, archives, patches,
        # wrappers and helper artifacts. Fixed-output seeds are artifacts too.
        fixed = any("hash" in o or "hashAlgo" in o for o in node["outputs"].values())
        node.update(name=name, pname=pname, version=version,
                    heavy=pname in HEAVY and isinstance(version, str)
                    and name == pname + "-" + version and not fixed)
    return nodes


def selected_items(descriptor):
    require(descriptor["schema"] == "tvp.latest-descriptor/v1", "Descriptor schema differs")
    require(descriptor["metadata"]["schema"] == "tvp.latest-tests/v1", "Selection schema differs")
    items = [descriptor["aggregate"]]
    families = descriptor["metadata"]["families"]
    require({r["job"] for r in families.values()} == set(descriptor["batches"]), "Batch selection differs")
    for row in families.values():
        items.append({"drv": row["packageDRV"], "outputs": row["outputs"]})
        batch = descriptor["batches"][row["job"]]
        require(batch["drv"] == row["jobDRV"], "Batch producer differs")
        items.extend([batch, *batch["tests"].values()])
    return items


def identities(descriptor, nodes):
    required = set()
    for item in selected_items(descriptor):
        drv = path(item["drv"], drv=True)
        require(drv in nodes, "Missing selected producer: " + drv)
        actual = nodes[drv]["outputs"]
        expected = item["outputs"]
        require(all("path" in o for o in actual.values()), "Unresolved selected output: " + drv)
        paths = {o["path"] for o in actual.values()}
        require(paths == set(expected.values() if isinstance(expected, dict) else expected),
                "Selected output identity differs: " + drv)
        require(nodes[drv]["system"] == descriptor["system"], "Selected system differs")
        if item is not descriptor["aggregate"]:
            required.update(paths)
    require(required == set(descriptor["requiredOutputs"]), "Required output membership differs")
    return required | {descriptor["aggregate"]["out"]}


def realization_targets(descriptor, nodes, valid):
    """Cached aggregates do not retain every sibling or selected package output."""
    missing = {}
    for item in selected_items(descriptor)[1:]:
        outputs = nodes[item["drv"]]["outputs"]
        missing.setdefault(item["drv"], set()).update(
            name for name, output in outputs.items() if output["path"] not in valid)
    return [descriptor["aggregate"]["drv"] + "^*"] + [
        drv + "^" + ",".join(sorted(names)) for drv, names in sorted(missing.items()) if names]


def preparation(descriptor, nodes, valid, unresolved=None):
    """Postorder over needed recipes only; cached parents need no lost ancestors."""
    demanded = {}
    for drv, node in nodes.items():
        for child, selectors in node["inputDrvs"].items():
            require(child in nodes, "Missing native node: " + child)
            require(not selectors["dynamicOutputs"], "Unresolved dynamic demand: " + child)
            require(set(selectors["outputs"]) <= set(nodes[child]["outputs"]), "Unknown demanded output")
    roots = {descriptor["aggregate"]["drv"]: list(descriptor["aggregate"]["outputs"])}
    for batch in descriptor["batches"].values():
        for item in [batch, *batch["tests"].values()]:
            roots.setdefault(item["drv"], []).extend(item["outputs"])
    for row in descriptor["metadata"]["families"].values():
        roots.setdefault(row["packageDRV"], []).extend(nodes[row["packageDRV"]]["outputs"])
    todo = list(roots.items())
    needed = set()
    while todo:
        drv, outputs = todo.pop()
        node = nodes[drv]
        demanded.setdefault(drv, set()).update(outputs)
        if any("path" not in node["outputs"][n] for n in outputs) and unresolved is not None:
            unresolved.add(drv)
            continue
        for n in outputs:
            require("path" in node["outputs"][n], "Unresolved demanded path: " + drv + "^" + n)
        if all(node["outputs"][n]["path"] in valid for n in outputs) or drv in needed:
            continue
        needed.add(drv)
        todo.extend((child, s["outputs"]) for child, s in node["inputDrvs"].items())
    if unresolved:
        return None  # Never return a partial heavy plan before resolving demand.
    # Iterative DFS: dependencies before consumers, including intervening small nodes.
    order, done, active = [], set(), set()
    for root in sorted(needed):
        stack = [(root, False)]
        while stack:
            drv, end = stack.pop()
            if end:
                active.remove(drv); done.add(drv); order.append(drv)
            elif drv not in done:
                require(drv not in active, "Native graph cycle: " + drv)
                active.add(drv)
                stack.append((drv, True))
                stack.extend((c, False) for c in sorted(nodes[drv]["inputDrvs"], reverse=True) if c in needed)
    return [{"drv": drv, "name": nodes[drv]["name"],
             "outputs": {n: nodes[drv]["outputs"][n]["path"] for n in sorted(demanded[drv])}}
            for drv in order if nodes[drv]["heavy"]]


def preflight(descriptor, nodes, store=None):
    """Resolve only demanded fixed outputs; cached ancestors remain pruned."""
    store = store or Store()
    resolutions = []

    def resolve(drvs):
        paths = set()
        for drv in sorted(drvs):
            row = store.fixed_output(drv, nodes[drv])
            output = nodes[drv]["outputs"][row["output"]]
            require("path" not in output, "Fixed-output resolution changed an existing identity")
            output.update(path=row["path"], pathState="known", pathEvidence=row["evidence"])
            paths.add(row["path"])
            resolutions.append(row)
        return paths

    # Selected packages can themselves be fixed-output derivations. Their Nix
    # descriptor paths are checked by identities after the native query.
    resolve({item["drv"] for item in selected_items(descriptor)
             if any("path" not in o for o in nodes[item["drv"]]["outputs"].values())})
    identities(descriptor, nodes)
    known = {o["path"] for n in nodes.values() for o in n["outputs"].values() if "path" in o}
    valid = store.valid(known)
    while True:
        pending = set()
        requests = preparation(descriptor, nodes, valid, pending)
        if not pending:
            return valid, requests, resolutions
        # One metadata query per demanded fixed derivation, never one per
        # ordinary output. Newly resolved path validity is batched per frontier.
        valid.update(store.valid(resolve(pending)))


def retain(run, paths, store=None):
    """Nix prints root names, not output paths. Validate every actual target."""
    paths = set(paths)
    require(not any(p.endswith(".drv") for p in paths), "Recipe rooting must use the reference manifest, never --realise .drv")
    if not paths:
        return []
    require((store or Store()).valid(paths) == paths, "Refuse roots for invalid paths")
    key = hashlib.sha256("\n".join(sorted(paths)).encode()).hexdigest()
    prefix = run / "roots" / ("valid-" + key)
    result = subprocess.run(["nix-store", "--add-root", str(prefix), "--indirect", "--realise",
                             "--stdin", "--max-jobs", "0", "--option", "builders", "",
                             "--option", "substituters", ""], input="\n".join(sorted(paths)) + "\n",
                            text=True, capture_output=True, check=True, timeout=120)
    roots = result.stdout.splitlines()
    require(len(roots) == len(paths) and len(set(roots)) == len(paths), "Unexpected root stdout")
    targets = set()
    records = []
    for value in roots:
        root = Path(value)
        require(root.parent == prefix.parent and re.fullmatch(re.escape(prefix.name) + r"(?:-\d+)?", root.name),
                "Unowned root returned")
        require(root.is_symlink(), "Root is not a symlink")
        target = str(root.resolve(strict=True))
        targets.add(target)
        records.append({"root": str(root), "target": target})
    require(targets == paths, "Root targets differ")
    return records


def verify_outputs(descriptor, nodes, store=None):
    expected = identities(descriptor, nodes)
    require((store or Store()).valid(expected | {descriptor["source"]}) == expected | {descriptor["source"]},
            "Missing selected output/source (including declared siblings)")
    links = 0

    def directory(output, members):
        nonlocal links
        root = Path(output)
        require(root.is_dir() and {p.name for p in root.iterdir()} == set(members), "Link membership differs: " + output)
        for name, target in members.items():
            p = root / name
            require(p.is_symlink() and os.readlink(p) == target and p.exists(), "Link target differs: " + str(p))
            links += 1

    directory(descriptor["aggregate"]["out"], {n: b["out"] for n, b in descriptor["batches"].items()})
    for batch in descriptor["batches"].values():
        directory(batch["out"], {n: t["out"] for n, t in batch["tests"].items()})
    return {"validSelectedOutputs": len(expected), "links": links, "allDeclaredSiblings": True,
            "availabilityOnly": True, "freshExecutionCertified": False}

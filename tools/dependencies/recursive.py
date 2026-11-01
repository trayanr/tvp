"""Intended native build graphs. Protocol scope: Nix derivation show JSON v4."""

from collections import Counter, deque
import json
import os
import re
import subprocess


STORE = "/nix/store/"
STORE_NAME = re.compile(r"[0-9abcdfghijklmnpqrsvwxyz]{32}-[A-Za-z0-9+._?=-]+\Z")
OUTPUT_NAME = re.compile(r"[A-Za-z_][A-Za-z0-9_+-]*\Z")
LIMITS = [
    "Native inputDrvs prove build reachability, not execution of a hook or branch.",
    "Input sources include files, archives and helper text; their semantic role is unknown unless evidenced.",
    "Registration covers definitions or substrate controls, not all bytes built from TVP source.",
    "Pure evaluation functions/libraries and external host Nix/strace interfaces need not appear as drv nodes.",
    "Intended recipes only: installed outputs' registered derivers are not queried or substituted.",
    "No output realization, substitution or network traversal; evaluation may instantiate recipes/metadata.",
]


def path(value, *, drv=False):
    if not isinstance(value, str):
        raise ValueError("Expected store path string")
    name = value[len(STORE):] if value.startswith(STORE) else value
    if not STORE_NAME.fullmatch(name) or drv and not name.endswith(".drv"):
        raise ValueError(f"Invalid {'derivation ' if drv else ''}store path: {value!r}")
    return STORE + name


def mapping(value, label):
    if not isinstance(value, dict):
        raise ValueError(f"Expected object: {label}")
    return value


def strings(value, label):
    if not isinstance(value, list) or any(not isinstance(x, str) for x in value):
        raise ValueError(f"Expected string array: {label}")
    return sorted(set(value))


def output_name(value):
    if not isinstance(value, str) or not OUTPUT_NAME.fullmatch(value):
        raise ValueError(f"Invalid output name: {value!r}")
    return value


def selection(value):
    value = mapping(value, "input drv selection")
    if set(value) != {"outputs", "dynamicOutputs"}:
        raise ValueError("Expected outputs and dynamicOutputs in v4 input drv selection")
    return {
        "outputs": [output_name(x) for x in strings(value["outputs"], "selected outputs")],
        "dynamicOutputs": {output_name(k): selection(v) for k, v in sorted(
            mapping(value["dynamicOutputs"], "dynamicOutputs").items())},
    }


def normalize(document):
    if not isinstance(document, dict) or type(document.get("version")) is not int or document["version"] != 4:
        raise ValueError("Unsupported native derivation JSON: expected version 4 (Nix 2.34)")
    nodes = {}
    for key, raw in sorted(mapping(document.get("derivations"), "derivations").items()):
        drv = path(key, drv=True)
        if drv in nodes:
            raise ValueError(f"Duplicate normalized derivation: {drv}")
        raw = mapping(raw, drv)
        inputs = mapping(raw.get("inputs"), "inputs")
        drvs = mapping(inputs.get("drvs"), "inputs.drvs")
        outputs = {}
        for name, value in sorted(mapping(raw.get("outputs"), "outputs").items()):
            output_name(name)
            value = mapping(value, "output")
            # Preserve hash/method and deferred/CA fields without inventing paths.
            out = dict(value)
            if "path" in out:
                out["path"] = path(out["path"])
            out["pathState"] = "known" if "path" in out else "unresolved"
            outputs[name] = out
        if not outputs:
            raise ValueError(f"No declared outputs: {drv}")
        builder, system = raw.get("builder"), raw.get("system")
        if not isinstance(builder, str) or not builder or not isinstance(system, str) or not system:
            raise ValueError(f"Invalid builder/system: {drv}")
        dependencies = {}
        for child, selectors in sorted(drvs.items()):
            child = path(child, drv=True)
            if child in dependencies:
                raise ValueError(f"Duplicate normalized input: {child}")
            dependencies[child] = selection(selectors)
        nodes[drv] = {
            "builder": builder, "system": system, "outputs": outputs,
            "inputDrvs": dict(sorted(dependencies.items())),
            "inputSrcs": sorted({path(p) for p in strings(inputs.get("srcs"), "inputs.srcs")}),
        }
    return dict(sorted(nodes.items()))


def select_roots(manifest, labels):
    if manifest.get("schema") != 1:
        raise ValueError("Expected dependencyRoots schema 1")
    catalogue = mapping(manifest.get("roots"), "roots")
    groups = mapping(manifest.get("groups"), "groups")
    labels = labels or ["@" + manifest["defaultGroup"]]
    names = set()
    for label in labels:
        if label.startswith("@"):
            if label[1:] not in groups:
                raise ValueError(f"Unknown root group {label!r}; available: {', '.join('@'+k for k in groups)}")
            names.update(strings(groups[label[1:]], "root group"))
        else:
            names.add(label)
    if not names:
        raise ValueError("Root selection is empty")
    result = {}
    for name in sorted(names):
        if name not in catalogue:
            raise ValueError(f"Unknown root label: {name!r}; use --list-roots")
        row = dict(mapping(catalogue[name], name))
        if row.get("drv") is not None:
            row["drv"] = path(row["drv"], drv=True)
        elif (row.get("status") or {}).get("level") != "broken":
            raise ValueError(f"Root has no intended recipe: {name}")
        row["outputs"] = [output_name(x) for x in strings(row.get("outputs"), "root outputs")]
        if not row["outputs"] or not isinstance(row.get("scope"), str):
            raise ValueError(f"Invalid root registration: {name}")
        result[name] = row
    return result


def inventory(manifest, roots, document, errors=()):
    nodes = normalize(document)
    diagnostics = list(errors)
    # One deterministic multi-source shortest-path forest. Shared nodes and root
    # aliases are represented once; full root/node path products are not stored.
    witnesses = {}
    queue = deque()
    build_seen = set()
    for name, row in roots.items():
        drv = row["drv"]
        if drv is None:
            diagnostics.append({"kind": "broken-root", "root": name, "status": row["status"]})
        elif drv not in nodes:
            diagnostics.append({"kind": "missing-root", "root": name, "drv": drv})
        else:
            for out in row["outputs"]:
                if out not in nodes[drv]["outputs"]:
                    diagnostics.append({"kind": "missing-root-output", "root": name, "output": out})
            if drv not in build_seen:
                build_seen.add(drv)
                witnesses[drv] = {"root": name, "parent": None, "edge": None}
                queue.append(drv)
    sources = {}
    edges = 0
    dynamic = 0
    while queue:
        parent = queue.popleft()
        for child, selectors in nodes[parent]["inputDrvs"].items():
            edges += 1
            if selectors["dynamicOutputs"]:
                dynamic += 1
                diagnostics.append({"kind": "unresolved-dynamic-input", "parent": parent, "drv": child})
            if child not in nodes:
                diagnostics.append({"kind": "missing-node", "parent": parent, "drv": child})
            else:
                for out in selectors["outputs"]:
                    if out not in nodes[child]["outputs"]:
                        diagnostics.append({"kind": "missing-input-output", "parent": parent, "drv": child, "output": out})
            if child not in build_seen:
                build_seen.add(child)
                witnesses[child] = {"root": witnesses[parent]["root"], "parent": parent, "edge": "input-derivation"}
                if child in nodes:
                    queue.append(child)
        for src in nodes[parent]["inputSrcs"]:
            sources.setdefault(src, {"role": "source-or-metadata-artifact", "evidence": "native inputs.srcs"})
            if src not in witnesses:
                witnesses[src] = {"root": witnesses[parent]["root"], "parent": parent, "edge": "input-source"}
    # Kahn detects cycles in the actual reachable drv graph without recursion limits.
    reachable = build_seen & nodes.keys()
    indegree = {p: 0 for p in reachable}
    for p in reachable:
        for child in nodes[p]["inputDrvs"]:
            if child in indegree:
                indegree[child] += 1
    pending = deque(sorted(p for p, degree in indegree.items() if degree == 0))
    processed = 0
    while pending:
        p = pending.popleft()
        processed += 1
        for child in nodes[p]["inputDrvs"]:
            if child in indegree:
                indegree[child] -= 1
                if indegree[child] == 0:
                    pending.append(child)
    if processed != len(reachable):
        diagnostics.append({"kind": "cycle", "nodes": sorted(p for p, degree in indegree.items() if degree)})
    registrations = {}
    for name, row in sorted(manifest["roots"].items()):
        if row.get("drv"):
            registrations.setdefault(path(row["drv"], drv=True), []).append({
                "label": name, "scope": row["scope"], "evidence": row["evidence"]})
    borrowed = {}
    for row in manifest.get("borrowed", []):
        borrowed.setdefault(path(row["drv"], drv=True), []).append(row)
    output_registry = {}
    for row in manifest.get("outputRegistrations", []):
        output_registry.setdefault(path(row["path"]), []).append(row)
    classes = Counter()
    result_nodes = {}
    for drv in sorted(reachable):
        node = nodes[drv]
        evidence = registrations.get(drv, [])
        output_evidence = [row for out in node["outputs"].values() if "path" in out
                           for row in output_registry.get(out["path"], [])]
        classification = "registered-definition" if evidence else "explicit-borrowed" if drv in borrowed else "unclassified"
        if not evidence and drv not in borrowed and any(r["source"] == "substrate" for r in output_evidence):
            classification = "registered-substrate-output"
        classes[classification] += 1
        result_nodes[drv] = {**node, "classification": classification, "registrations": evidence,
                             "borrowedEvidence": borrowed.get(drv, []), "outputRegistrations": output_evidence}
    diagnostics = sorted(diagnostics, key=lambda x: json.dumps(x, sort_keys=True))
    return {
        "schema": 1, "protocol": "nix-derivation-json-v4", "state": "partial" if diagnostics else "complete",
        "roots": roots, "nodes": result_nodes, "sources": dict(sorted(sources.items())),
        "witnesses": dict(sorted(witnesses.items())), "diagnostics": diagnostics,
        "summary": {"roots": len(roots), "queriedRoots": sum(r["drv"] in nodes for r in roots.values()),
                    "derivations": len(result_nodes), "derivationEdges": edges,
                    "sourceInputs": len(sources), "sourceEdges": sum(len(n["inputSrcs"]) for n in result_nodes.values()),
                    "dynamicEdges": dynamic, "classifications": dict(sorted(classes.items()))},
        "limits": LIMITS,
    }


def explain(result, target):
    target = path(target)
    if target not in result["witnesses"]:
        raise ValueError(f"Target is not reachable from selected roots: {target}")
    chain = []
    current = target
    while current is not None:
        entry = result["witnesses"][current]
        chain.append({"path": current, "edge": entry["edge"]})
        current = entry["parent"]
    return {"root": result["witnesses"][target]["root"], "chain": list(reversed(chain))}


def collect(snapshot, labels, target=None, list_roots=False):
    command = ["nix", "eval", "--json", "--offline", "--no-write-lock-file",
               "--option", "allow-import-from-derivation", "false",
               snapshot["flake"] + "#legacyPackages." + snapshot["system"] + ".dependencyRoots"]
    manifest = json.loads(subprocess.check_output(command, text=True))
    roots = select_roots(manifest, labels)
    if list_roots:
        return {"schema": 1, "state": "catalogue", "defaultGroup": manifest["defaultGroup"],
                "groups": manifest["groups"], "roots": manifest["roots"], "limits": LIMITS}
    requested = sorted({row["drv"] for row in roots.values() if row["drv"]})
    # Query valid recipes only, so an unavailable root does not erase other roots.
    available = [p for p in requested if os.path.isfile(p)]
    errors = []
    document = {"version": 4, "derivations": {}}
    command = ["nix", "derivation", "show", "--offline", "--option", "allow-import-from-derivation", "false", "--recursive", "--stdin"]
    if available:
        query = subprocess.run(command, input="\n".join(available) + "\n", capture_output=True, text=True)
        if query.returncode:
            errors.append({"kind": "native-query-failed", "returnCode": query.returncode, "stderr": query.stderr})
        else:
            document = query.stdout
    try:
        if isinstance(document, str):
            document = json.loads(document)
        result = inventory(manifest, roots, document, errors)
    except ValueError as error:
        result = inventory(manifest, roots, {"version": 4, "derivations": {}}, [
            {"kind": "invalid-native-metadata", "message": str(error)}, *errors])
    result["query"] = {"command": command, "availableRootRecipes": len(available), "requestedRootRecipes": len(requested)}
    result["excludedBrokenRoots"] = {k: v for k, v in manifest["roots"].items() if v["drv"] is None}
    if target:
        result["explanation"] = explain(result, target)
    return result


def print_human(result, details=False):
    if result["state"] == "catalogue":
        print("Default recursive roots: @" + result["defaultGroup"])
        print("Groups: " + ", ".join("@" + k for k in result["groups"]))
        for name, row in sorted(result["roots"].items()):
            print(f"{name} [{row['scope']}] {row['drv'] or 'excluded: ' + json.dumps(row['status'], sort_keys=True)}")
        return
    summary = result["summary"]
    print(f"Recursive build inputs: {result['state']}; {summary['queriedRoots']}/{summary['roots']} roots, "
          f"{summary['derivations']} derivations, {summary['derivationEdges']} build edges, {summary['sourceInputs']} source/metadata inputs")
    print("Registrations: " + ", ".join(f"{k} {v}" for k, v in summary["classifications"].items()))
    print(f"Excluded declared-broken roots: {len(result['excludedBrokenRoots'])} (see --list-roots)")
    for diagnostic in result["diagnostics"]:
        print("Incomplete: " + json.dumps(diagnostic, sort_keys=True))
    if "explanation" in result:
        witness = result["explanation"]
        print("Root: " + witness["root"])
        for step in witness["chain"]:
            print(f"  {step['edge'] or 'root'}: {step['path']}")
    if details:
        for drv, node in result["nodes"].items():
            print(f"{node['classification']} {drv}")
    for limit in result["limits"]:
        print(limit)

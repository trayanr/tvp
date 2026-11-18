"""Report external package inputs from the evaluated Nix build graph."""

import argparse
from collections import defaultdict, deque
import json
import os
from pathlib import Path
import subprocess
import sys

import recursive


PACKAGE_ROOTS = ["@canonical", "@variants", "@composition"]


def package_manifest(snapshot, labels):
    # Keep package/base registrations for identification. Evaluating every
    # check and tool eagerly would expand unrelated test graphs.
    omitted = [
        scope for scope in ("tools", "checks")
        if not any(label == "@" + scope or label.startswith(scope + ".") for label in labels)
    ]
    apply = """
      manifest:
      let
        omitted = builtins.fromJSON %s;
      in
      manifest // {
        roots = builtins.removeAttrs manifest.roots (builtins.filter (
          name: builtins.any (scope: builtins.substring 0 (builtins.stringLength scope + 1) name == scope + ".") omitted
        ) (builtins.attrNames manifest.roots));
        groups = builtins.removeAttrs manifest.groups omitted;
      }
    """ % json.dumps(json.dumps(omitted))
    return recursive.evaluate(snapshot, "dependencyRoots", apply)


def graph_report(graph):
    nodes = graph["nodes"]
    consumers = defaultdict(list)
    parents = defaultdict(list)
    for name, row in graph["roots"].items():
        consumers[row["drv"]].append(name)
    for parent, node in nodes.items():
        for child in node["inputDrvs"]:
            parents[child].append(parent)

    def affected_roots(drv):
        seen = {drv}
        pending = deque(seen)
        affected = []
        while pending:
            current = pending.popleft()
            affected.extend(consumers.get(current, []))
            for parent in parents[current]:
                if parent not in seen:
                    seen.add(parent)
                    pending.append(parent)
        return sorted(affected)

    external = []
    unclassified = []
    for drv, node in nodes.items():
        evidence = node["borrowedEvidence"]
        if evidence:
            names = sorted({row["attribute"] for row in evidence if row["source"]})
            external.append({
                "name": Path(drv).stem.split("-", 1)[1],
                "derivation": drv,
                "providers": names or sorted({row["attribute"] for row in evidence}),
                "consumers": affected_roots(drv),
                "witness": recursive.explain(graph, drv),
                "evidence": evidence,
            })
        elif node["classification"] == "unclassified" and not node["outputRegistrations"]:
            witness = graph["witnesses"][drv]
            unclassified.append({"derivation": drv, "root": witness["root"], "via": witness["parent"]})
    return {
        "mode": "build-graph",
        "state": graph["state"],
        "roots": len(graph["roots"]),
        "externalPackages": sorted(external, key=lambda row: (row["name"], row["derivation"])),
        "unclassifiedDerivations": unclassified,
        "excludedBrokenRoots": graph["excludedBrokenRoots"],
        "diagnostics": graph["diagnostics"],
    }


def realized_report(declarations):
    roots = declarations["runtimeRoots"]
    registered = {row["path"] for row in declarations["registry"]}
    boundaries = defaultdict(set)
    for row in declarations["registry"]:
        if row["source"] in ("binary", "mixed"):
            boundaries[row["path"]].add(row["source"])
    paths = set(roots.values())
    invalid = set()
    if paths:
        invalid = set(subprocess.check_output(
            ["nix-store", "--check-validity", "--print-invalid", "--stdin"],
            input="\n".join(sorted(paths)) + "\n", text=True,
        ).splitlines())
    available = paths - invalid
    references = {}
    if available:
        references = json.loads(subprocess.check_output(
            ["nix", "path-info", "--offline", "--json-format", "1", "--json", "--recursive", "--stdin"],
            input="\n".join(sorted(available)) + "\n", text=True,
        ))
    unregistered = {}
    runtime_boundaries = {}
    for package, root in roots.items():
        if root not in available:
            continue
        seen = {root}
        pending = [root]
        while pending:
            for path in references[pending.pop()]["references"]:
                if path not in seen:
                    seen.add(path)
                    pending.append(path)
        missing = sorted(seen - registered)
        if missing:
            unregistered[package] = missing
        found = {
            kind: sorted(path for path in seen if kind in boundaries.get(path, ()))
            for kind in ("binary", "mixed")
        }
        if any(found.values()):
            runtime_boundaries[package] = found
    return {
        "mode": "realized",
        "checked": len(roots) - sum(path in invalid for path in roots.values()),
        "unbuilt": [name for name, path in roots.items() if path in invalid],
        "unregisteredPaths": unregistered,
        "runtimeBoundaries": runtime_boundaries,
    }


def declared_report(data):
    return {
        "mode": "declared",
        "declarations": data["declarations"],
        "registration": {
            "paths": len({row["path"] for row in data["registry"]}),
            "entries": data["registry"],
        },
    }


def print_report(report):
    if report["mode"] == "build-graph":
        print(f"Evaluated build graph: {report['state']}, {report['roots']} roots")
        providers = report["externalPackages"]
        print(f"Confirmed external packages: {len(providers)}")
        for entry in providers:
            print(f"  {entry['name']} ({', '.join(entry['providers'])}), "
                  f"used by {len(entry['consumers'])} roots")
        if report["unclassifiedDerivations"]:
            print("Unclassified inputs, including helpers and downloads, are available in --json.")
        if report["excludedBrokenRoots"]:
            print(f"Declared broken roots in the catalogue: {len(report['excludedBrokenRoots'])}")
        for failure in report["diagnostics"]:
            print("Incomplete: " + json.dumps(failure, sort_keys=True))
    elif report["mode"] == "declared":
        for row in report["declarations"]:
            print(f"{row['package']} [{row['kind']}] {row['source']}, {row['status']}")
            builder = row["recipe"]["builder"] or "unknown"
            definition = row["recipe"]["definition"] or "unknown"
            print(f"  recipe {builder} ({definition}), base {row['base'] or 'none'}")
            if row["sourceUrl"]:
                print(f"  source URL {row['sourceUrl']}")
            if row["upstreamUrl"] and row["upstreamUrl"] != row["sourceUrl"]:
                print(f"  upstream URL {row['upstreamUrl']}")
            if row["blob"]:
                print(f"  binary boundary {row['blob']['reason']}")
                print(f"  replacement {row['blob']['needs']}")
        print(f"Registered output paths: {report['registration']['paths']}")
    else:
        print(f"Local runtime closures: {report['checked']} checked, {len(report['unbuilt'])} unavailable")
        for name, paths in report["unregisteredPaths"].items():
            print(name)
            for path in paths:
                print(f"  {path}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument("--declared", action="store_true", help="Show source and recipe declarations")
    modes.add_argument("--realized", action="store_true", help="Inspect locally available runtime closures")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--root", action="append", help="Build graph root or group, e.g. packages.coreutils_9_5 or @tools")
    args = parser.parse_args()
    if args.root and (args.declared or args.realized):
        parser.error("--root applies to the evaluated build graph")
    data_dir = Path(__file__).resolve().parent
    try:
        snapshot = {"flake": (data_dir / "flake").read_text(),
                    "system": os.environ["TVP_PROVENANCE_SYSTEM"]}
        if args.realized or args.declared:
            data = recursive.evaluate(snapshot, "provenanceDeclarations")
            report = realized_report(data) if args.realized else declared_report(data)
        else:
            labels = args.root or PACKAGE_ROOTS
            report = graph_report(recursive.collect_manifest(package_manifest(snapshot, labels), labels))
    except (OSError, KeyError, ValueError, subprocess.CalledProcessError) as error:
        print(f"tvp-provenance: {error}", file=sys.stderr)
        return 1
    if args.json:
        print(json.dumps(report, indent=2))
    else:
        print_report(report)
    return int(report.get("state") == "partial")


if __name__ == "__main__":
    raise SystemExit(main())

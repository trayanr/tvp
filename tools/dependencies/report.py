"""Inventory evaluated dependency choices without realizing package outputs."""

import argparse
from collections import Counter
import json
import os
from pathlib import Path
import subprocess
import sys


KINDS = ("latest", "major", "minor", "finer", "exact", "override", "variant", "foreign", "unknown")
SCOPES = ("ordinary", "public-variant", "construction", "broken", "composition", "artifact")


def stable(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"))


def selector_kind(edge):
    selection = edge.get("selection")
    if not isinstance(selection, dict):
        return "foreign" if edge.get("resolved", {}).get("tvp") is False else "unknown"
    kind = selection.get("kind")
    if kind not in KINDS:
        return "unknown"
    if kind not in ("foreign", "unknown") and not (
        isinstance(selection.get("namespace"), str) and isinstance(selection.get("selector"), str)
    ):
        return "unknown"
    return kind


def edge_key(edge):
    return edge.get("scope"), edge.get("consumer"), edge.get("dependency")


def declaration_key(edge):
    """A shared definition is one decision, however many releases use it."""
    return stable([
        edge.get("scope"), edge.get("family"), edge.get("definition"),
        edge.get("dependency"), edge.get("selection"),
        edge.get("resolved", {}).get("output"), edge.get("reason"),
    ])


def counts(edges):
    by_kind = Counter(selector_kind(edge) for edge in edges)
    by_scope = Counter(edge.get("scope", "unknown") for edge in edges)
    declarations = {declaration_key(edge): edge for edge in edges}
    declarations_by_kind = Counter(selector_kind(edge) for edge in declarations.values())
    selectors = {
        stable([selection["namespace"], selection["selector"]])
        for edge in edges
        if isinstance((selection := edge.get("selection")), dict)
        and isinstance(selection.get("namespace"), str)
        and isinstance(selection.get("selector"), str)
    }
    families = {edge["resolved"]["family"] for edge in edges if edge.get("resolved", {}).get("family")}
    releases = {
        stable([resolved.get("family"), resolved["version"]])
        for edge in edges
        if (resolved := edge.get("resolved", {})).get("family") and resolved.get("version")
    }
    producers = {edge["resolved"]["drv"] for edge in edges if edge.get("resolved", {}).get("drv")}
    return {
        "expandedEdges": len(edges),
        "distinctDeclarationChoices": len(declarations),
        "requestedSelectors": len(selectors),
        "dependencyFamilies": len(families),
        "resolvedReleases": len(releases),
        "resolvedProducers": len(producers),
        "byKind": {kind: by_kind[kind] for kind in KINDS},
        "declarationsByKind": {kind: declarations_by_kind[kind] for kind in KINDS},
        "byScope": {scope: by_scope[scope] for scope in (*SCOPES, *sorted(set(by_scope) - set(SCOPES)))},
    }


def summarize(inventory):
    if inventory.get("schema") != 1 or not isinstance(inventory.get("edges"), list):
        raise ValueError("Expected dependency inventory schema 1 with an edges array")
    edges = inventory["edges"]
    seen = Counter(edge_key(edge) for edge in edges)
    duplicates = [
        {"scope": key[0], "consumer": key[1], "dependency": key[2], "occurrences": number}
        for key, number in seen.items() if number > 1
    ]
    return {
        "all": counts(edges),
        "scopes": {scope: counts([edge for edge in edges if edge.get("scope") == scope])
                   for scope in (*SCOPES, *sorted({e.get("scope", "unknown") for e in edges} - set(SCOPES)))},
        "supportDeclarations": len(inventory.get("support", [])),
        "duplicateEdges": duplicates,
        "unknownEdges": [
            {"scope": edge.get("scope"), "consumer": edge.get("consumer"),
             "dependency": edge.get("dependency"), "selection": edge.get("selection"),
             "details": edge.get("details", "No unambiguous evaluated selector intent")}
            for edge in edges if selector_kind(edge) == "unknown"
        ],
    }


def compare(before, after):
    def index(inventory):
        result = {}
        for edge in inventory["edges"]:
            key = edge_key(edge)
            if key in result:
                raise ValueError(f"Cannot compare duplicate dependency edge {key!r}")
            result[key] = edge
        return result

    old, new = index(before), index(after)
    changes = []
    for key in sorted(old.keys() | new.keys()):
        left, right = old.get(key), new.get(key)
        if left is None or right is None or (
            left.get("selection") != right.get("selection") or
            left.get("resolved") != right.get("resolved") or
            left.get("reason") != right.get("reason")
        ):
            changes.append({
                "scope": key[0], "consumer": key[1], "dependency": key[2],
                "change": "added" if left is None else "removed" if right is None else "changed",
                "before": left, "after": right,
                "resolvedChanged": left is None or right is None or left.get("resolved") != right.get("resolved"),
                "releaseChanged": left is None or right is None or any(
                    left.get("resolved", {}).get(field) != right.get("resolved", {}).get(field)
                    for field in ("family", "version")
                ),
            })
    return {
        "before": counts(before["edges"]), "after": counts(after["edges"]),
        "changedEdges": len(changes),
        "changedResolvedIdentities": sum(change["resolvedChanged"] for change in changes),
        "changedResolvedReleases": sum(change["releaseChanged"] for change in changes),
        "changes": changes,
    }


def evaluate(flake, system):
    metadata = json.loads(subprocess.check_output(
        ["nix", "flake", "metadata", "--json", "--no-write-lock-file", flake], text=True
    ))
    source = metadata.get("path")
    if not isinstance(source, str) or not source.startswith("/nix/store/"):
        raise ValueError("Nix did not return an immutable store source for --flake")
    immutable = "path:" + source
    inventory = json.loads(subprocess.check_output(
        ["nix", "eval", "--json", "--offline", "--no-write-lock-file",
         immutable + "#legacyPackages." + system + ".dependencyInventory"], text=True
    ))
    inventory["snapshot"] = {
        "requestedFlake": flake, "flake": immutable, "system": system,
        "locked": metadata.get("locked"), "revision": metadata.get("revision"),
        "fingerprint": metadata.get("fingerprint"),
    }
    return inventory


def filtered(edges, args):
    return [edge for edge in edges
            if (not args.kind or selector_kind(edge) in args.kind)
            and (not args.scope or edge.get("scope") in args.scope)
            and (not args.family or edge.get("family") in args.family
                 or edge.get("resolved", {}).get("family") in args.family)
            and (not args.exceptions or edge.get("reason")
                 or isinstance(edge.get("selection"), dict) and edge["selection"].get("reason"))]


def print_human(inventory, args):
    edges = filtered(inventory["edges"], args)
    summary = counts(edges)
    print(f"{summary['expandedEdges']} release dependency edges; "
          f"{summary['distinctDeclarationChoices']} distinct definition/dependency choices")
    print(f"{summary['requestedSelectors']} requested namespace/selectors; "
          f"{summary['dependencyFamilies']} dependency families; "
          f"{summary['resolvedReleases']} resolved releases; "
          f"{summary['resolvedProducers']} resolved producers")
    print("Kind          edges  choices")
    for kind in KINDS:
        print(f"{kind:12} {summary['byKind'][kind]:6} {summary['declarationsByKind'][kind]:8}")
    print("Scopes: " + ", ".join(f"{scope} {number}" for scope, number in summary["byScope"].items()))
    print(f"Infrastructure support declarations: {len(inventory.get('support', []))}")
    duplicates = inventory["summary"]["duplicateEdges"]
    if duplicates:
        print(f"Duplicate edge keys: {len(duplicates)} (all occurrences included)")
    if args.details:
        for edge in edges:
            selection = edge.get("selection")
            request = (f"{selection.get('namespace')}.{selection.get('selector')}"
                       if isinstance(selection, dict) else "unknown request")
            resolved = edge.get("resolved", {})
            print(f"{edge.get('scope')} {edge.get('consumer')} [{edge.get('definition')}] "
                  f"{edge.get('dependency')}: {selector_kind(edge)} {request} -> "
                  f"{resolved.get('family')} {resolved.get('version')} [{resolved.get('output')}]")
            reason = edge.get("reason") or (selection.get("reason") if isinstance(selection, dict) else None)
            if reason:
                print("  reason: " + (reason if isinstance(reason, str) else stable(reason)))
            if selector_kind(edge) == "unknown":
                print("  details: " + stable(edge.get("details", selection)))
    comparison = inventory.get("comparison")
    if comparison:
        print(f"Compared: {comparison['changedEdges']} changed edges; "
              f"{comparison['changedResolvedReleases']} changed resolved releases; "
              f"{comparison['changedResolvedIdentities']} changed resolved identities")
        if args.details:
            for change in comparison["changes"]:
                if change["resolvedChanged"]:
                    before = (change["before"] or {}).get("resolved", {})
                    after = (change["after"] or {}).get("resolved", {})
                    print(f"  {change['scope']} {change['consumer']}.{change['dependency']}: "
                          f"{before.get('family')} {before.get('version')} {before.get('drv')} -> "
                          f"{after.get('family')} {after.get('version')} {after.get('drv')}")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--flake", default=".", help="Flake to snapshot once before evaluation (default: current directory)")
    parser.add_argument("--system", default=os.environ.get("TVP_DEPENDENCIES_SYSTEM", "x86_64-linux"))
    parser.add_argument("--json", action="store_true", help="Emit full evaluated inventory, summary and snapshot provenance")
    parser.add_argument("--details", action="store_true", help="Show individual matching choices and reasons")
    parser.add_argument("--kind", action="append", choices=KINDS, help="Filter by selector kind; repeatable")
    parser.add_argument("--scope", action="append", help="Filter by inventory scope; repeatable")
    parser.add_argument("--family", action="append", help="Filter by consumer or dependency family; repeatable")
    parser.add_argument("--exceptions", action="store_true", help="Show choices with structured compatibility/pin reasons")
    parser.add_argument("--compare", type=Path, help="Compare against a previous --json snapshot")
    args = parser.parse_args(argv)
    try:
        inventory = evaluate(args.flake, args.system)
        inventory["summary"] = summarize(inventory)
        if args.compare:
            before = json.loads(args.compare.read_text())
            summarize(before)
            inventory["comparison"] = compare(before, inventory)
        if args.json:
            if args.kind or args.scope or args.family or args.exceptions:
                inventory["filtered"] = filtered(inventory["edges"], args)
                inventory["filteredSummary"] = counts(inventory["filtered"])
            print(json.dumps(inventory, indent=2, sort_keys=True))
        else:
            print_human(inventory, args)
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"tvp-dependencies: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

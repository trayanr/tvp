"""Audit actual closures against TVP registration and reviewed legacy debt."""
import json
import os
import sys


def audit(roots, references, registered, baseline):
    result = {"clean": [], "legacy": {}, "unexpected": {}, "stale": {}}
    for name, root in sorted(roots.items()):
        pending, seen = [root], set()
        while pending:
            path = pending.pop()
            if path in seen:
                continue
            if path not in references:
                raise ValueError(f"Missing reference graph for {name}: {path}")
            seen.add(path)
            pending.extend(references[path])
        foreign = seen - registered
        allowed = set(baseline.get(name, {}).get("paths", []))
        if foreign:
            result["legacy"][name] = sorted(foreign)
        else:
            result["clean"].append(name)
        if foreign - allowed:
            result["unexpected"][name] = sorted(foreign - allowed)
        if allowed - foreign:
            result["stale"][name] = sorted(allowed - foreign)
    for name in baseline.keys() - roots.keys():
        result["stale"][name] = baseline[name]["paths"]
    return result


def main():
    with open(os.environ["NIX_ATTRS_JSON_FILE"], encoding="utf-8") as handle:
        attrs = json.load(handle)
    with open(sys.argv[1], encoding="utf-8") as handle:
        baseline = json.load(handle)
    for name, item in baseline.items():
        if not item.get("reason") or not item.get("needs") or not item.get("paths"):
            raise ValueError(f"Incomplete legacy runtime declaration: {name}")
    graph = {entry["path"]: entry["references"] for entry in attrs["runtime"]}
    result = audit(attrs["runtimeRoots"], graph, set(attrs["registeredPaths"]), baseline)
    with open(attrs["outputs"]["out"], "w", encoding="utf-8") as handle:
        json.dump(result, handle, indent=2, sort_keys=True)
        handle.write("\n")
    print(f"Runtime closures: {len(result['clean'])} clean, {len(result['legacy'])} with reviewed legacy boundaries")
    for category in ("unexpected", "stale"):
        for name, paths in result[category].items():
            print(f"{category}: {name}", file=sys.stderr)
            for path in paths:
                print(f"  {path}", file=sys.stderr)
    return int(bool(result["unexpected"] or result["stale"]))


if __name__ == "__main__":
    sys.exit(main())

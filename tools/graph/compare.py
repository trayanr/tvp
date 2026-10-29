"""Compare evaluated producer graphs; additions do not redefine old producers."""
import argparse
import json
import sys


def read_snapshot(path):
    with open(path, encoding="utf-8") as handle:
        snapshot = json.load(handle)
    if snapshot.get("schema") != 1 or not isinstance(snapshot.get("entries"), dict):
        raise ValueError(f"{path}: unsupported or malformed graph snapshot")
    for name, value in snapshot["entries"].items():
        if not isinstance(value, dict) or not all(
            isinstance(value.get(field), str) for field in ("drv", "out")
        ):
            raise ValueError(f"{path}: invalid producer {name}")
    return snapshot["entries"]


def compare(before, after, allowances=(), output_only=False):
    common = before.keys() & after.keys()
    changed = sorted(
        name for name in common
        if (before[name]["out"] != after[name]["out"] if output_only else before[name] != after[name])
    )
    allowances = set(allowances)
    return {
        "compared": len(common),
        "added": sorted(after.keys() - before.keys()),
        "removed": sorted(before.keys() - after.keys()),
        "changed": {
            name: {"before": before[name], "after": after[name]} for name in changed
        },
        "allowedChanges": sorted(allowances & set(changed)),
        "unexpectedChanges": sorted(set(changed) - allowances),
        # An unused allowance is a typo or stale policy, never permission for a
        # later unexpected change. Removals require review and always fail.
        "unusedAllowances": sorted(allowances - set(changed)),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("before")
    parser.add_argument("after")
    parser.add_argument("--allow-change", action="append", default=[], metavar="EXACT_NAME")
    parser.add_argument("--out", action="store_true", help="compare output paths only")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    try:
        result = compare(read_snapshot(args.before), read_snapshot(args.after), args.allow_change, args.out)
    except (ValueError, OSError) as error:
        parser.error(str(error))
    failed = any(result[key] for key in ("removed", "unexpectedChanges", "unusedAllowances"))
    if args.json:
        print(json.dumps(result, indent=2, sort_keys=True))
    else:
        print(f"Compared {result['compared']} producers; {len(result['added'])} added; {len(result['removed'])} removed")
        for key in ("removed", "unexpectedChanges", "allowedChanges", "unusedAllowances"):
            for name in result[key]:
                print(f"{key}: {name}")
        if not failed:
            print("All existing producers are unchanged or explicitly reviewed.")
    return int(failed)


if __name__ == "__main__":
    sys.exit(main())

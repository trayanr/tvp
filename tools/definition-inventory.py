"""Inventory Nix authoring APIs and their static source references without Nix."""

import argparse
import collections
import json
from pathlib import Path
import re
import subprocess
import sys


# These are lexical criteria, not a Nix parser or a migration admission policy.
CALL_PREFIX = r"(?<![\w-])(?:[\w.-]+\.)?"
PATTERNS = {
    "mkBase calls": CALL_PREFIX + r"mkBase\s*\{",
    "mkBase definitions": r"^\s*mkBase\s*=",
    "legacyEnvironment calls": CALL_PREFIX + r"legacyEnvironment\s*\{",
    "legacyEnvironment definitions": r"^\s*legacyEnvironment\s*=",
    "mkDefs calls": CALL_PREFIX + r"mkDefs\s*\{",
    "mkFamily calls": CALL_PREFIX + r"mkFamily\s*\{",
    "mkVersions mentions": CALL_PREFIX + r"mkVersions\b",
    "packageArgs assignments": r"^\s*packageArgs(?:\.[\w-]+)*\s*=",
    "infra assignments": r"^\s*infra(?:\.[\w-]+)*\s*=",
    "extraArgs assignments": r"^\s*extraArgs(?:\.[\w-]+)*\s*=",
    "constructor assignments": r"^\s*constructor\s*=",
    "dependencyNames assignments": r"^\s*dependencyNames\s*=",
    "helpers assignments": r"^\s*helpers\s*=",
    "platform assignments": r"^\s*platform\s*=",
    "base assignments": r"^\s*base\s*=",
    "standardTools mentions": r"\bstandardTools\b",
    "mkDerivation calls": CALL_PREFIX + r"mkDerivation\s*(?:\{|\()",
    "constructionRecipe mentions": r"\bconstructionRecipe\b",
    "private legacy-base mentions": r"\b__legacyBases\b",
    "selectTools method mentions": r"\.selectTools\b",
}
OLD_AUTHORING = {
    "mkDefs calls",
    "packageArgs assignments",
    "infra assignments",
    "extraArgs assignments",
}
RELATIVE_PATH = re.compile(r"(?<![\w/])\.\.?/[^\s;{}()\[\]\"'`]+")


def git(root, *args):
    return subprocess.check_output(["git", "-C", str(root), *args]).decode()


def category(path):
    parts = path.split("/")
    if parts[0] == "pkgs" and len(parts) == 4 and parts[-1] == "default.nix":
        return "ordinary-entrypoint"
    if "tests" in parts or "fixtures" in parts:
        return "tests-or-fixtures"
    return {
        "pkgs": "package-procedure-or-retained",
        "lib": "library-implementation",
        "bases": "base-or-retained-construction",
        "bootstrap": "bootstrap-producer",
    }.get(parts[0], "repository-tool-or-assembly")


def uncomment(source):
    # Preserve line numbers. Inline comments, strings and scope nesting are not
    # parsed: callers must inspect hits before treating them as migration debt.
    source = re.sub(
        r"/\*.*?\*/", lambda match: "\n" * match[0].count("\n"), source, flags=re.S
    )
    return "\n".join(
        "" if line.lstrip().startswith("#") else line
        for line in source.splitlines()
    )


def static_references(root, sources):
    references = collections.defaultdict(list)
    for path, source in sources.items():
        for match in RELATIVE_PATH.finditer(source):
            literal = match[0].rstrip(",")
            target = (root / path).parent / literal
            try:
                relative = target.resolve().relative_to(root)
            except (OSError, ValueError):
                continue
            if (root / relative).is_dir():
                relative /= "default.nix"
            if relative.as_posix() in sources:
                references[relative.as_posix()].append({
                    "file": path,
                    "line": source.count("\n", 0, match.start()) + 1,
                    "literal": literal,
                })
    return references


def inventory(root, include_untracked=False):
    tracked = set(filter(None, git(root, "ls-files", "-z", "--", "*.nix").split("\0")))
    untracked = set()
    if include_untracked:
        untracked = set(filter(None, git(
            root, "ls-files", "--others", "--exclude-standard", "-z", "--", "*.nix"
        ).split("\0")))
    sources = {
        path: uncomment((root / path).read_text(encoding="utf-8"))
        for path in sorted(tracked | untracked)
        if (root / path).is_file()
    }
    expressions = {name: re.compile(pattern, re.M) for name, pattern in PATTERNS.items()}
    files = {}
    for path, source in sources.items():
        hits = {
            name: [source.count("\n", 0, match.start()) + 1 for match in rx.finditer(source)]
            for name, rx in expressions.items()
        }
        files[path] = {
            "category": category(path),
            "tracked": path in tracked,
            "hits": {name: lines for name, lines in hits.items() if lines},
        }
    summaries = {}
    for name in PATTERNS:
        matching = [record for record in files.values() if name in record["hits"]]
        summaries[name] = {
            "files": len(matching),
            "sites": sum(len(record["hits"][name]) for record in matching),
            "byCategory": {
                kind: {
                    "files": sum(record["category"] == kind for record in matching),
                    "sites": sum(
                        len(record["hits"][name])
                        for record in matching if record["category"] == kind
                    ),
                }
                for kind in sorted({record["category"] for record in matching})
            },
        }
    references = static_references(root, sources)
    candidates = [
        path for path, record in files.items()
        if path.startswith("pkgs/") and OLD_AUTHORING.intersection(record["hits"])
    ]
    forwarders = [
        path for path, source in sources.items()
        if re.fullmatch(r"import\s+\./[^\s;]+", source.strip())
    ]
    return {
        "schema": "tvp.definition-inventory/v1",
        "root": str(root),
        "scope": "tracked-and-nonignored-untracked" if include_untracked else "tracked",
        "nixFiles": len(files),
        "untrackedNixFiles": sum(not record["tracked"] for record in files.values()),
        "categories": dict(sorted(collections.Counter(
            record["category"] for record in files.values()
        ).items())),
        "criteria": PATTERNS,
        "summary": summaries,
        "oldAuthoringCandidates": candidates,
        "pureImportForwarders": forwarders,
        "files": {path: record for path, record in files.items() if record["hits"]},
        "staticReferences": {
            path: references[path] for path in sorted(set(candidates + forwarders))
        },
        "limits": [
            "Lexical matches after removing block and full-line comments; not a Nix parser.",
            "Mentions can occur in strings, nested attributes or test fixtures.",
            "Relative path references do not establish evaluation or runtime liveness.",
            "No Nix evaluation, build, store query or qualification is performed.",
            "Counts are informational; old API occurrences are not automatically defects.",
        ],
    }


def render_text(report, details=False):
    print(f"Nix definition inventory: {report['root']}")
    print(f"Scope: {report['scope']}; {report['nixFiles']} files "
          f"({report['untrackedNixFiles']} untracked)")
    print(f"Ordinary family entrypoints: {report['categories'].get('ordinary-entrypoint', 0)}")
    print("\nCriterion                          All files/sites    Ordinary files/sites")
    for name, counts in report["summary"].items():
        ordinary = counts["byCategory"].get("ordinary-entrypoint", {"files": 0, "sites": 0})
        all_count = f"{counts['files']}/{counts['sites']}"
        ordinary_count = f"{ordinary['files']}/{ordinary['sites']}"
        print(f"{name:34} {all_count:>15} {ordinary_count:>23}")
    candidates = report["oldAuthoringCandidates"]
    referenced = sum(bool(report["staticReferences"][path]) for path in candidates)
    print(f"\nOld-authoring candidate files: {len(candidates)}; "
          f"{referenced} have static source references.")
    print(f"Pure import forwarders: {len(report['pureImportForwarders'])}.")
    print("References and lexical matches establish neither runtime liveness nor qualification.")
    if details:
        for path, record in report["files"].items():
            print(f"\n{record['category']}: {path}")
            for name, lines in record["hits"].items():
                print(f"  {name}: {', '.join(map(str, lines))}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1],
                        help="repository root (default: parent of this script's tools directory)")
    parser.add_argument("--include-untracked", action="store_true",
                        help="also inspect nonignored untracked Nix files during migration")
    output = parser.add_mutually_exclusive_group()
    output.add_argument("--json", action="store_true", help="emit counts, criteria, hits and references")
    output.add_argument("--text", action="store_true", help="emit the compact text summary (default)")
    parser.add_argument("--details", action="store_true", help="include per-file hits in text output")
    args = parser.parse_args()
    try:
        report = inventory(args.root.resolve(), args.include_untracked)
    except (OSError, UnicodeError, subprocess.CalledProcessError) as error:
        parser.error(str(error))
    if args.json:
        print(json.dumps(report, indent=2, sort_keys=True))
    else:
        render_text(report, args.details)
    return 0


if __name__ == "__main__":
    sys.exit(main())

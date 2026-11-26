"""Compare audit candidates against public advisory controls without building packages."""

import argparse
from collections import Counter
from datetime import datetime, timezone
import hashlib
import importlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

from audit import package_identity


BACKENDS = ("grype", "osv")
RESOLVE = r"""
let
  flake = builtins.getFlake (builtins.getEnv "TVP_EVALUATION_SOURCE");
  pkgs = import flake.inputs.nixpkgs { system = "x86_64-linux"; };
  tvp = import flake.outPath { inherit pkgs; };
  selectors = builtins.fromJSON (builtins.getEnv "TVP_EVALUATION_SELECTORS");
in builtins.listToAttrs (map (selector:
  let package = tvp.canonical.${selector}; in {
    name = selector;
    value = {
      inherit (package) pname version drvPath;
      security = package.tvp.security or null;
    };
  }
) selectors)
"""


def _bytes(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":")).encode()


def _digest(value):
    return hashlib.sha256(_bytes(value)).hexdigest()


def validate_matrix(matrix):
    if (not isinstance(matrix, dict) or type(matrix.get("schema")) is not int
            or matrix["schema"] != 1 or not isinstance(matrix.get("cases"), list) or not matrix["cases"]):
        raise ValueError("Evaluation matrix requires schema = 1 and nonempty cases")
    seen = set()
    for case in matrix["cases"]:
        if not isinstance(case, dict) or not isinstance(case.get("id"), str) or not re.fullmatch(r"[a-z0-9][a-z0-9_-]*", case["id"]):
            raise ValueError("Evaluation cases require safe unique IDs")
        if case["id"] in seen:
            raise ValueError("Evaluation case IDs must be unique")
        seen.add(case["id"])
        if any(not isinstance(case.get(key), str) or not case[key].strip() for key in ("name", "version")):
            raise ValueError(f"Evaluation case {case['id']} requires a package name and version")
        if type(case.get("expectedAffected")) is not bool:
            raise ValueError("Evaluation expectations must be explicit booleans")
        origin = case.get("origin")
        if origin not in ("tvp-metadata", "upstream-version-control"):
            raise ValueError("Evaluation case origin must identify TVP metadata or an upstream control")
        if (origin == "tvp-metadata") != ("selector" in case):
            raise ValueError("Only TVP metadata cases declare an actual package selector")
        for field in ("selector", "profileSelector"):
            if field in case and (not isinstance(case[field], str) or not re.fullmatch(r"[A-Za-z0-9_+-]+", case[field])):
                raise ValueError("Evaluation selectors must be canonical package names")
        advisory = case.get("advisory")
        if (not isinstance(advisory, dict) or not isinstance(advisory.get("id"), str) or not advisory["id"]
                or not isinstance(advisory.get("url"), str) or not advisory["url"].startswith("https://")
                or not isinstance(advisory.get("aliases", []), list)
                or any(not isinstance(item, str) or not item for item in advisory.get("aliases", []))):
            raise ValueError("Evaluation controls require an advisory ID, primary source URL and aliases")
    return matrix


def _nix_json(arguments, **kwargs):
    result = subprocess.run(["nix", *arguments], check=True, capture_output=True, text=True, **kwargs)
    return json.loads(result.stdout)


def resolve_components(tvp, matrix):
    """Freeze a flake snapshot, then read only the requested package metadata."""
    validate_matrix(matrix)
    root = Path(tvp).resolve(strict=True)
    metadata = _nix_json(["flake", "metadata", "--json", "--no-write-lock-file", "--no-update-lock-file", str(root)])
    if not isinstance(metadata.get("locked"), dict) or not isinstance(metadata.get("path"), str):
        raise ValueError("Nix did not identify an immutable TVP source snapshot")
    snapshot = Path(metadata["path"])
    lock = snapshot / "flake.lock"
    source = {
        "flake": str(root), "snapshotPath": str(snapshot), "locked": metadata["locked"],
        "lockSha256": hashlib.sha256(lock.read_bytes()).hexdigest(),
    }
    selectors = sorted({case.get("selector") or case.get("profileSelector") for case in matrix["cases"]} - {None})
    environment = {**os.environ, "TVP_EVALUATION_SOURCE": str(snapshot),
                   "TVP_EVALUATION_SELECTORS": json.dumps(selectors)}
    packages = _nix_json(["eval", "--impure", "--json", "--option", "allow-import-from-derivation", "false", "--expr", RESOLVE], env=environment)
    resolved = []
    for case in matrix["cases"]:
        selector = case.get("selector") or case.get("profileSelector")
        package = packages.get(selector) if selector else None
        if selector and (not isinstance(package, dict) or package.get("pname") != case["name"]):
            raise ValueError(f"Selector {selector} does not identify {case['name']}")
        if "selector" in case and package.get("version") != case["version"]:
            raise ValueError(f"Selector {selector} version differs from the evaluation control")
        component = {
            "id": "evaluation-" + case["id"], "case": case["id"], "name": case["name"],
            "version": case["version"], "origin": case["origin"],
            "identity": package_identity(package.get("security") if package else None, case["version"]),
        }
        if selector:
            component["profileSource"] = selector
        if "selector" in case:
            component["drvPath"] = package["drvPath"]
        resolved.append(component)
    return source, resolved


def score(matrix, backend_result):
    """Score only the named advisory controls; other findings are not false positives."""
    validate_matrix(matrix)
    results = backend_result.get("results")
    if not isinstance(results, list):
        raise ValueError("Candidate result has no component results")
    by_id = {}
    expected_ids = {"evaluation-" + case["id"] for case in matrix["cases"]}
    for result in results:
        if (not isinstance(result, dict) or not isinstance(result.get("component"), str)
                or result["component"] not in expected_ids or result["component"] in by_id
                or result.get("status") not in ("scanned", "unsupported")
                or not isinstance(result.get("vulnerabilities"), list)):
            raise ValueError("Candidate returned an unknown, duplicate or malformed component")
        if result["status"] == "unsupported" and (not result.get("reason") or result["vulnerabilities"]):
            raise ValueError("Unsupported candidate results require a reason and no findings")
        by_id[result["component"]] = result
    if set(by_id) != expected_ids:
        raise ValueError("Candidate omitted evaluation components")
    cases = []
    for case in matrix["cases"]:
        result = by_id["evaluation-" + case["id"]]
        advisory_ids = set()
        for finding in result["vulnerabilities"]:
            if (not isinstance(finding, dict) or not isinstance(finding.get("id"), str) or not finding["id"]
                    or not isinstance(finding.get("aliases", []), list)
                    or any(not isinstance(alias, str) for alias in finding.get("aliases", []))):
                raise ValueError("Candidate returned invalid advisory identifiers")
            advisory_ids.update([finding["id"], *finding.get("aliases", [])])
        target_ids = {case["advisory"]["id"], *case["advisory"].get("aliases", [])}
        matched = bool(advisory_ids & target_ids)
        if result["status"] == "unsupported":
            outcome = "unsupported"
        elif case["expectedAffected"]:
            outcome = "affected_detected" if matched else "affected_missed"
        else:
            outcome = "fixed_matched" if matched else "fixed_clear"
        row = {"case": case["id"], "outcome": outcome, "targetMatched": matched,
               "observedAdvisoryIds": sorted(advisory_ids), "findingCount": len(result["vulnerabilities"])}
        if "reason" in result:
            row["reason"] = result["reason"]
        cases.append(row)
    counts = Counter(row["outcome"] for row in cases)
    return {"counts": {name: counts[name] for name in (
        "affected_detected", "affected_missed", "fixed_clear", "fixed_matched", "unsupported",
    )}, "cases": cases}


def format_comparison(comparison):
    lines = ["Advisory control comparison", "Scope: package/version matching; build applicability remains unassessed."]
    for name, entry in comparison["backends"].items():
        if entry["status"] == "failed":
            lines.append(f"{name}: FAILED — {entry['error']['message']}")
        else:
            counts = entry["score"]["counts"]
            lines.append(f"{name}: {counts['affected_detected']} affected controls detected, "
                         f"{counts['affected_missed']} missed, {counts['fixed_clear']} fixed controls clear, "
                         f"{counts['fixed_matched']} fixed controls matched, {counts['unsupported']} unsupported "
                         f"({entry['durationSeconds']:.3f}s)")
            for row in entry["score"]["cases"]:
                lines.append(f"  {row['case']}: {row['outcome']}")
    return "\n".join(lines)


def evaluate(matrix, components, output, backends=BACKENDS, *, source=None, cache_dir=None, offline=False):
    validate_matrix(matrix)
    backends = tuple(backends)
    if not backends or len(set(backends)) != len(backends) or any(name not in BACKENDS for name in backends):
        raise ValueError("Choose distinct evaluation backends: grype, osv")
    if {item.get("id") for item in components} != {"evaluation-" + case["id"] for case in matrix["cases"]} or len(components) != len(matrix["cases"]):
        raise ValueError("Resolved components do not match the evaluation matrix")
    output = Path(output)
    output.mkdir(parents=True, exist_ok=False)
    source = source if source is not None else {"kind": "provided-components", "sourceProvenance": "not supplied"}
    def write(name, value):
        (output / name).write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")
    write("matrix.json", matrix)
    write("source.json", source)
    write("components.json", components)
    comparison = {"schema": 1, "createdAt": datetime.now(timezone.utc).isoformat(),
                  "matrixSha256": _digest(matrix), "componentsSha256": _digest(components),
                  "sourceSha256": _digest(source), "offline": offline, "backends": {}}
    for name in backends:
        started = time.monotonic()
        print(f"Evaluating {name} against {len(components)} public controls...", file=sys.stderr, flush=True)
        try:
            provider = importlib.import_module("audit_" + name)
            report = provider.scan(components, offline=offline,
                                   cache_dir=Path(cache_dir) / name if cache_dir is not None else None)
            if (not isinstance(report, dict) or not isinstance(report.get("backend"), dict)
                    or report["backend"].get("name") != name or not isinstance(report.get("database"), dict)
                    or not report["database"]):
                raise ValueError("Candidate omitted scanner/database evidence")
            evaluated = score(matrix, report)
            entry = {"status": "completed", "report": report, "score": evaluated}
        except Exception as error:
            # Keep backend failures, including unexpected adapter defects, as
            # evidence and still attempt the other explicitly requested candidate.
            entry = {"status": "failed", "error": {"type": type(error).__name__, "message": str(error)}}
        entry["durationSeconds"] = round(time.monotonic() - started, 3)
        write(name + ".json", entry)
        comparison["backends"][name] = {key: value for key, value in entry.items() if key != "report"}
    write("comparison.json", comparison)
    (output / "comparison.txt").write_text(format_comparison(comparison) + "\n")
    return comparison


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tvp", type=Path, default=Path("."))
    parser.add_argument("--matrix", type=Path, default=Path(__file__).with_name("security-evaluation.json"))
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--backend", action="append", choices=BACKENDS)
    parser.add_argument("--cache-dir", type=Path)
    parser.add_argument("--offline", action="store_true")
    args = parser.parse_args()
    try:
        if args.output.exists():
            raise ValueError("Evaluation output already exists; choose a new evidence directory")
        matrix = validate_matrix(json.loads(args.matrix.read_text()))
        source, components = resolve_components(args.tvp, matrix)
        comparison = evaluate(matrix, components, args.output, args.backend or BACKENDS,
                              source=source, cache_dir=args.cache_dir, offline=args.offline)
        print(format_comparison(comparison))
        return int(any(entry["status"] == "failed" for entry in comparison["backends"].values()))
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"tvp audit evaluation: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())

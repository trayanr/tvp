"""Certify one exact latest-per-family partial attempt, never a full catalogue."""

import json
import os
from pathlib import Path
import socket
import subprocess

from verifier import (Store, atomic_report, digest, execution, load, require,
                      validate_plan, validate_terminal_state, worker_observation)

SCOPE = "representative latest release per family"


def structured_attributes(metadata):
    # Nix's current derivation JSON has a decoded field; older responses retain
    # the structured JSON in env. These are observations, never recipe defaults.
    if "structuredAttrs" in metadata:
        attrs = metadata["structuredAttrs"]
    else:
        attrs = json.loads(metadata["env"]["__json"])
    require(isinstance(attrs, dict), "Malformed structured derivation attributes")
    return attrs


def projection(reference, catalogue, selection):
    """The reviewed catalogue records aliases; names never determine versions."""
    require(selection["schema"] == "tvp.representative-selection/v1", "Selection schema differs")
    require(catalogue["schema"] == "tvp.representative-catalogue/v1", "Catalogue schema differs")
    subject = {k: reference[k] for k in ("revision", "source", "system")}
    require(catalogue["subject"] == selection["subject"] == subject, "Selection/catalogue subject differs")
    require(selection["validationScope"] == SCOPE, "Selection scope differs")
    families = catalogue["families"]
    require(set(selection["families"]) == set(families) and families, "Family membership differs")
    selected = set()
    for family, row in families.items():
        chosen = selection["families"][family]
        alias = row["alias"]
        require(chosen == alias, "Latest alias differs: " + family)
        require(alias["family"] == family and alias["version"] and alias["job"], "Invalid family alias")
        versions = row["versions"]
        require(alias in versions, "Alias absent from eligible versions")
        require(len({v["job"] for v in versions}) == len(versions), "Duplicate family versions")
        require(alias["job"] not in selected, "Duplicate selected family job")
        selected.add(alias["job"])
    for category in ("profiles", "compatibility", "checks"):
        rows = selection[category]
        require(isinstance(rows, list), "Invalid " + category)
        for row in rows:
            name = row["job"]
            require(isinstance(row["reason"], str) and row["reason"].strip(), "Selection reason missing")
            require(name not in selected, "Duplicate selected job: " + name)
            if category == "profiles":
                require(name in catalogue["profiles"], "Unknown profile")
                profile = catalogue["profiles"][name]
                require(profile["version"] == families[profile["family"]]["alias"]["version"],
                        "Profile is not the current family release")
            if category == "compatibility":
                require(any(name == version["job"] for family in families.values()
                            for version in family["versions"]), "Unknown compatibility release")
            if category == "checks":
                require(name.startswith("check-") and name != "check-package-runtime-ownership",
                        "All-version ownership is not a representative check")
            selected.add(name)
    require({"check-package-runtime-ownership-latest", "check-runtime-policy-latest"} <= selected,
            "Scoped ownership/policy checks required")
    names = {j["name"] for j in reference["jobs"]}
    require(selected <= names, "Unknown selected jobs")
    require(selection["selectedJobs"] == sorted(selected), "Selected membership differs")
    require(selection["omittedJobs"] == sorted(names - selected), "Omitted membership differs")
    eligible = {v["job"] for row in families.values() for v in row["versions"]}
    require(eligible <= names, "Eligible family suite missing from full reference")
    require(selection["omittedOrdinaryVersions"] == len(eligible - selected), "Omitted version count differs")
    indexed = {j["name"]: j for j in reference["jobs"]}
    for row in families.values():
        require(indexed[row["alias"]["job"]]["drv"] == row["alias"]["jobDRV"], "Alias suite DRV differs")
    return reference | {"jobs": [j for j in reference["jobs"] if j["name"] in selected]}


def observe_selected(plan, catalogue, selection, store):
    items = [item for job in plan["jobs"] for item in [job] + job["tests"]]
    expected = {}
    for item in items:
        previous = expected.setdefault(item["drv"], item["outputs"])
        require(set(previous) == set(item["outputs"]), "Conflicting selected output mappings")
    selected_names = {job["name"] for job in plan["jobs"]}
    packages = [v for row in catalogue["families"].values() for v in row["versions"]]
    packages += list(catalogue["profiles"].values())
    for package in packages:
        if package["job"] in selected_names:
            previous = expected.setdefault(package["packageDRV"], package["outputs"])
            require(set(previous) == set(package["outputs"]), "Conflicting package output mappings")
    metadata = store.derivations(expected)
    for drv, outputs in expected.items():
        actual = [o.get("path") for o in metadata[drv]["outputs"].values()]
        require(set(actual) == set(outputs) and metadata[drv]["system"] == plan["system"],
                "Selected DRV/output/system binding differs: " + drv)
    outputs = {p for paths in expected.values() for p in paths} | {plan["source"]}
    require(store.valid(outputs) == outputs, "Missing selected output/source")
    links = 0
    for job in plan["jobs"]:
        if not job["tests"]:
            continue
        directory = Path(job["outputs"][0])
        require(directory.is_dir() and {p.name for p in directory.iterdir()} == {t["name"] for t in job["tests"]},
                "Selected suite link membership differs")
        for test in job["tests"]:
            link = directory / test["name"]
            require(link.is_symlink() and os.readlink(link) == test["outputs"][0] and link.exists(),
                    "Selected test link differs")
            links += 1
    jobs = {j["name"]: j for j in plan["jobs"]}
    ownership_job = jobs["check-package-runtime-ownership-latest"]
    roots = {r["alias"]["job"]: r["alias"]["out"] for r in catalogue["families"].values()}
    attrs = structured_attributes(metadata[ownership_job["drv"]])
    require(attrs["runtimeRoots"] == roots, "Actual ownership derivation roots differ")
    ownership = load(ownership_job["outputs"][0])
    require(ownership["unexpected"] == ownership["stale"] == {}, "Selected ownership audit failed")
    require(set(ownership["clean"]) | set(ownership["legacy"]) == set(roots), "Ownership result roots differ")
    policy = load(jobs["check-runtime-policy-latest"]["outputs"][0])
    require(policy["roots"] == sorted(roots) and set(policy["legacy"]) <= set(roots), "Ownership policy scope differs")
    baseline = load(Path(plan["source"]) / "audits/runtime-baseline.json")
    require(policy["legacy"] == {k: value for k, value in baseline.items() if k in roots},
            "Selected reviewed baseline rows differ")
    require(policy["registeredPaths"] == attrs["registeredPaths"], "Ownership registry differs")
    return {"declaredOutputsAndSource": len(outputs), "selectedDerivations": len(expected),
            "primaryOutputLinks": links, "allDeclaredMultioutputs": True,
            "actualLocalStoreObservation": True, "ownershipRoots": len(roots),
            "ownershipPolicy": "Selected roots with unchanged reviewed baseline rows; strict unexpected/stale rejection",
            "fullAggregateObservedOrRequired": False}


def verify(args, store=None):
    inputs = {}
    report = {"schema": "tvp.representative-validation/v1", "validationScope": SCOPE,
              "full": False, "result": "FAIL", "inputs": inputs,
              "observationHost": socket.gethostname(), "limitations": [
                  "One partial attempt; omitted historical suites were evaluated, not certified as executed.",
                  "Validity and links prove availability, not fresh execution; no cache/readiness/CI approval."]}

    def read(path):
        path = Path(path).absolute()
        before = digest(path)
        value = load(path)
        require(digest(path) == before, "Input changed while reading")
        inputs[str(path)] = before
        return value

    try:
        run = args.run.absolute()
        require(run.resolve() == run, "Canonical run path required")
        plan, state = read(run / "plan.json"), read(run / "state.json")
        reference, catalogue, selection = map(read, (args.reference_plan, args.catalogue, args.selection_manifest))
        validate_plan(reference)
        report["counts"] = validate_plan(plan)
        require(selection["referencePlanSHA256"] == digest(args.reference_plan)
                and selection["catalogueSHA256"] == digest(args.catalogue), "Manifest input hashes differ")
        require(plan == projection(reference, catalogue, selection), "Exact selected plan projection differs")
        validate_terminal_state(plan, state, "raw", False)
        for key in ("revision", "source", "system"):
            require(plan[key] == getattr(args, "expect_" + key), "Expected subject differs: " + key)
        report["worker"] = worker_observation(run, state)
        report["coverage"] = observe_selected(plan, catalogue, selection, store or Store())
        report["subject"] = {k: plan[k] for k in ("revision", "source", "system")}
        report["subject"]["run"] = str(run)
        report["reference"] = {"mode": "exact-selected-projection", "fullCatalogueSuites": len(reference["jobs"]),
                               "omittedSuites": len(selection["omittedJobs"]),
                               "omittedOrdinaryVersions": selection["omittedOrdinaryVersions"],
                               "eligibleFamilies": len(catalogue["families"]),
                               "profiles": len(selection["profiles"]), "compatibilityCases": len(selection["compatibility"]),
                               "selectedChecks": len(selection["checks"]), "manifestSHA256": digest(args.selection_manifest)}
        for name in ("nix.log", "prepare.log"):
            inputs[str(run / name)] = digest(run / name)
        report["execution"] = execution(state, run / "nix.log", run / "prepare.log")
        require(all(digest(p) == h for p, h in inputs.items()), "Evidence changed during verification")
        report["result"] = "PASS"
    except (ValueError, OSError, KeyError, TypeError, subprocess.SubprocessError) as error:
        report["failure"] = str(error)
    return report


def add_parser(commands):
    parser = commands.add_parser("verify-representative", help=__doc__)
    for name in ("run", "reference-plan", "catalogue", "selection-manifest", "output"):
        parser.add_argument("--" + name, type=Path, required=True)
    for name in ("revision", "source", "system"):
        parser.add_argument("--expect-" + name, required=True)


def dispatch(args):
    report = verify(args)
    atomic_report(args.output, report, report["inputs"])
    print(json.dumps({"result": report["result"], "validationScope": SCOPE,
                      "report": str(args.output), "failure": report.get("failure")}))
    return int(report["result"] != "PASS")

"""Experimental Grype adapter for explicitly identified TVP components.

The input is a CycloneDX inventory, never a filesystem scan. Grype/Syft assigns
its own artifact IDs when decoding CycloneDX, so matches are correlated through
the exact supplied identities rather than assuming bom-ref survives decoding.
"""

import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
from urllib.parse import unquote


SEVERITIES = {"unknown", "negligible", "low", "medium", "high", "critical"}


def _text(value):
    return isinstance(value, str) and bool(value.strip()) and not any(ord(c) < 32 for c in value)


def _identity(component):
    """Accept exact versioned identities; do not invent CPEs from package names."""
    version = component.get("version")
    identity = component.get("identity")
    if not _text(version):
        return None, "package has no usable version"
    if not isinstance(identity, dict):
        return None, "package has no Grype identity"
    selected = {}
    if "purl" in identity:
        purl = identity["purl"]
        if not _text(purl) or not re.fullmatch(r"pkg:[a-z][a-z0-9.+-]*/[^\s]+", purl):
            return None, "package URL is invalid"
        path = purl.split("?", 1)[0].split("#", 1)[0]
        if "@" not in path or unquote(path.rsplit("@", 1)[1]) != version:
            return None, "package URL does not identify the selected version"
        selected["purl"] = purl
    if "cpe" in identity:
        cpe = identity["cpe"]
        if not _text(cpe) or any(c.isspace() for c in cpe):
            return None, "CPE is invalid"
        fields = re.split(r"(?<!\\):", cpe)
        if (len(fields) != 13 or fields[:2] != ["cpe", "2.3"]
                or fields[2] not in ("a", "o", "h")
                or any(value in ("", "*", "-") for value in fields[3:6])
                or re.sub(r"\\(.)", r"\1", fields[5]) != version):
            return None, "CPE does not identify the selected product and version"
        selected["cpe"] = cpe
    if not selected:
        return None, "package has no versioned CPE or package URL for Grype"
    return selected, None


def _strings(value, field):
    if value is None:
        return []
    if not isinstance(value, list) or not all(_text(item) for item in value):
        raise ValueError(f"Invalid Grype {field}: expected a list of strings")
    return value


def _matched_components(artifact, components):
    if not isinstance(artifact, dict) or not _text(artifact.get("id")):
        raise ValueError("Invalid Grype match artifact")
    if not _text(artifact.get("name")) or not _text(artifact.get("version")):
        raise ValueError("Grype match artifact has no name or version")
    purl = artifact.get("purl", "")
    if not isinstance(purl, str):
        raise ValueError("Invalid Grype artifact package URL")
    cpes = _strings(artifact.get("cpes", []), "artifact CPEs")
    matches = []
    for component, identity in components:
        if component["version"] != artifact["version"]:
            continue
        if "purl" in identity:
            equal = identity["purl"] == purl
        else:
            equal = component["name"] == artifact["name"] and identity["cpe"] in cpes
        if "cpe" in identity:
            equal = equal and identity["cpe"] in cpes
        if equal:
            matches.append(component["id"])
    if not matches:
        raise ValueError("Grype returned a match for an undeclared component identity")
    return matches


def _vulnerability(match):
    vulnerability = match.get("vulnerability")
    if not isinstance(vulnerability, dict) or not _text(vulnerability.get("id")):
        raise ValueError("Invalid Grype vulnerability")
    severity = vulnerability.get("severity", "unknown")
    if not isinstance(severity, str):
        raise ValueError("Invalid Grype vulnerability severity")
    severity = severity.lower() or "unknown"
    if severity not in SEVERITIES:
        severity = "unknown"
    summary = vulnerability.get("description", "")
    if not isinstance(summary, str):
        raise ValueError("Invalid Grype vulnerability description")
    fix = vulnerability.get("fix", {})
    if not isinstance(fix, dict):
        raise ValueError("Invalid Grype vulnerability fix")
    fixed = _strings(fix.get("versions", []), "fixed versions")
    details = match.get("matchDetails")
    if not isinstance(details, list) or not details:
        raise ValueError("Grype match has no matching evidence")
    methods = []
    for detail in details:
        if not isinstance(detail, dict) or not _text(detail.get("type")) or not _text(detail.get("matcher")):
            raise ValueError("Invalid Grype matching evidence")
        methods.append(f"{detail['matcher']}:{detail['type']}")
    urls = _strings(vulnerability.get("urls", []), "vulnerability URLs")
    source = vulnerability.get("dataSource", "")
    if not isinstance(source, str):
        raise ValueError("Invalid Grype vulnerability data source")
    url = next((url for url in [source, *urls] if url.startswith(("https://", "http://"))), None)
    namespace = vulnerability.get("namespace", "")
    if not isinstance(namespace, str):
        raise ValueError("Invalid Grype vulnerability namespace")
    # Related advisories are not necessarily interchangeable aliases. Retain
    # their IDs without using them to collapse distinct provider records.
    related = match.get("relatedVulnerabilities", [])
    if not isinstance(related, list):
        raise ValueError("Invalid Grype related vulnerabilities")
    related_ids = []
    for item in related:
        if not isinstance(item, dict) or not _text(item.get("id")):
            raise ValueError("Invalid Grype related vulnerability")
        if item["id"] != vulnerability["id"]:
            related_ids.append(item["id"])
    return {
        "id": vulnerability["id"],
        "aliases": [],
        "relatedIds": sorted(set(related_ids)),
        "summary": summary,
        "severity": severity,
        "url": url,
        "fixedVersions": sorted(set(fixed)),
        "match": ", ".join(sorted(set(methods))),
        "namespace": namespace,
    }


def _report(document, selected, results, offline):
    if not isinstance(document, dict) or not isinstance(document.get("matches"), list):
        raise ValueError("Grype response has no matches array")
    ignored = document.get("ignoredMatches", [])
    if not isinstance(ignored, list) or ignored:
        raise ValueError("Grype returned ignored matches; an unfiltered scan is required")
    descriptor = document.get("descriptor")
    if (not isinstance(descriptor, dict) or descriptor.get("name") != "grype"
            or not _text(descriptor.get("version"))):
        raise ValueError("Grype response has no scanner version metadata")
    database = descriptor.get("db")
    if (not isinstance(database, dict) or not database.get("schemaVersion")
            or not _text(database.get("built")) or database.get("valid") is not True
            or database.get("error")):
        raise ValueError("Grype response has no valid database metadata")
    artifacts = {}
    for match in document["matches"]:
        if not isinstance(match, dict):
            raise ValueError("Invalid Grype match")
        artifact = match.get("artifact")
        component_ids = _matched_components(artifact, selected)
        if artifact["id"] in artifacts and artifacts[artifact["id"]] != component_ids:
            raise ValueError("Grype artifact ID identifies inconsistent components")
        artifacts[artifact["id"]] = component_ids
        vulnerability = _vulnerability(match)
        for identifier in component_ids:
            if vulnerability not in results[identifier]["vulnerabilities"]:
                results[identifier]["vulnerabilities"].append(vulnerability)
    for result in results.values():
        result["vulnerabilities"].sort(key=lambda item: (item["id"], item.get("namespace", ""), item["match"]))
    return {
        "backend": {"name": "grype", "version": descriptor["version"]},
        "database": {
            "descriptor": database,
            "descriptorSha256": hashlib.sha256(json.dumps(database, sort_keys=True).encode()).hexdigest(),
            "offline": offline,
        },
        "results": list(results.values()),
    }


def scan(components, *, offline=False, cache_dir=None):
    """Scan supplied component identities with the caller's installed Grype."""
    results = {}
    selected = []
    for component in components:
        if not isinstance(component, dict) or not _text(component.get("id")) or not _text(component.get("name")):
            raise ValueError("Grype components require unique IDs and names")
        identifier = component["id"]
        if identifier in results:
            raise ValueError("Grype components require unique IDs")
        identity, reason = _identity(component)
        result = {"component": identifier, "status": "unsupported" if reason else "scanned", "vulnerabilities": []}
        if reason:
            result["reason"] = reason
        else:
            selected.append((component, identity))
        results[identifier] = result
    if not selected:
        return {"backend": {"name": "grype", "version": None},
                "database": {"offline": offline, "used": False}, "results": list(results.values())}
    executable = shutil.which("grype")
    if executable is None:
        raise RuntimeError("Grype is not available on PATH; install it before selecting the grype backend")
    executable = os.path.abspath(executable)
    sbom = {
        "bomFormat": "CycloneDX", "specVersion": "1.6", "version": 1,
        "components": [
            {"type": "library", "bom-ref": component["id"], "name": component["name"],
             "version": component["version"], **identity}
            for component, identity in selected
        ],
    }
    # An explicit config and sanitized backend environment prevent user-level
    # ignore rules, VEX documents or fix filters from hiding audit findings.
    configuration = {
        "check-for-app-update": False, "only-fixed": False, "only-notfixed": False,
        "ignore": [], "exclude": [], "vex-documents": [], "vex-add": [],
        "add-cpes-if-none": False, "external-sources": {"enable": False},
        "db": {"auto-update": not offline, "require-update-check": not offline},
    }
    environment = {key: value for key, value in os.environ.items() if not key.startswith(("GRYPE_", "SYFT_"))}
    environment.update({"GRYPE_CHECK_FOR_APP_UPDATE": "false", "GRYPE_EXTERNAL_SOURCES_ENABLE": "false",
                        "GRYPE_DB_AUTO_UPDATE": "false" if offline else "true"})
    if cache_dir is not None:
        environment["GRYPE_DB_CACHE_DIR"] = str(Path(cache_dir).expanduser().resolve() / "grype")
    with tempfile.TemporaryDirectory(prefix="tvp-grype-") as directory:
        sbom_path = Path(directory) / "components.cdx.json"
        config_path = Path(directory) / "config.yaml"
        sbom_path.write_text(json.dumps(sbom))
        config_path.write_text(json.dumps(configuration))
        try:
            process = subprocess.run(
                [executable, f"sbom:{sbom_path}", "--output", "json", "--config", str(config_path)],
                cwd=directory, env=environment, text=True, capture_output=True, timeout=360,
            )
        except subprocess.TimeoutExpired as error:
            raise RuntimeError("Grype scan timed out") from error
        if process.returncode != 0:
            raise RuntimeError(f"Grype scan failed (exit {process.returncode}): {process.stderr.strip()[-2000:]}")
        try:
            document = json.loads(process.stdout)
        except json.JSONDecodeError as error:
            raise ValueError("Grype returned invalid JSON") from error
    return _report(document, selected, results, offline)

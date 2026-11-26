"""Audit the resolved TVP selections with an explicitly chosen candidate backend."""

from collections import Counter
import hashlib
import importlib
import json
import re
from urllib.parse import quote

from report import format_output_scope


SEVERITIES = ("unknown", "negligible", "low", "medium", "high", "critical")
EXCLUDED_SCOPES = [
    "undeclared transitive dependencies",
    "language lockfile dependencies",
    "non-TVP packages",
    "application code and vulnerability reachability",
]


def package_identity(profile, version):
    """Expand TVP-owned upstream identifiers without guessing from package names."""
    if profile is None:
        return {}
    if not isinstance(profile, dict) or type(profile.get("schema")) is not int or profile["schema"] != 1:
        raise ValueError("Unsupported TVP security profile; expected schema = 1")
    version_specific = "upstreamVersion" in profile or (
        isinstance(profile.get("osv"), dict) and "version" in profile["osv"]
    )
    if version_specific and "forVersion" not in profile:
        raise ValueError("Version-specific TVP security identities must declare forVersion")
    if "forVersion" in profile:
        if (not isinstance(profile["forVersion"], str) or not profile["forVersion"]
                or any(not char.isprintable() or char.isspace() for char in profile["forVersion"])):
            raise ValueError("TVP security forVersion must identify the declared release")
        if profile["forVersion"] != version:
            return {}
    identity = {}
    if not isinstance(version, str) or not version:
        return identity
    if any(not char.isprintable() or char.isspace() for char in version):
        raise ValueError("TVP security versions must not contain whitespace or control characters")
    if "upstreamVersion" in profile:
        upstream = profile["upstreamVersion"]
        if (not isinstance(upstream, str) or not upstream
                or any(not char.isprintable() or char.isspace() for char in upstream)):
            raise ValueError("TVP security upstreamVersion must be a nonempty upstream release")
        identity["version"] = version = upstream
    if "purl" in profile:
        purl = profile["purl"]
        if not isinstance(purl, str) or not re.fullmatch(r"pkg:[a-z][a-z0-9.+-]*/[^@?#\s]+", purl):
            raise ValueError("TVP security purl must be an unversioned package URL")
        identity["purl"] = f"{purl}@{quote(version, safe='')}"

    def cpe_identity(cpe):
        if not isinstance(cpe, dict) or not all(
            isinstance(cpe.get(key), str) and re.fullmatch(r"[a-z0-9_.-]+", cpe[key])
            for key in ("vendor", "product")
        ) or cpe.get("part", "a") not in ("a", "o", "h"):
            raise ValueError("TVP security CPE must declare a valid vendor and product")
        # Escape CPE formatted-string punctuation; wildcard versions are never inferred.
        escaped = "".join(char if char.isascii() and (char.isalnum() or char in "._-")
                          else "\\" + char for char in version)
        return f"cpe:2.3:{cpe.get('part', 'a')}:{cpe['vendor']}:{cpe['product']}:{escaped}:*:*:*:*:*:*:*"

    if "cpe" in profile and "cpes" in profile:
        raise ValueError("TVP security profile must choose cpe or cpes")
    if "cpe" in profile:
        identity["cpe"] = cpe_identity(profile["cpe"])
    if "cpes" in profile:
        cpes = profile["cpes"]
        if not isinstance(cpes, list) or not cpes:
            raise ValueError("TVP security cpes must be a nonempty list")
        values = [cpe_identity(cpe) for cpe in cpes]
        if len(set(values)) != len(values):
            raise ValueError("TVP security cpes must be distinct")
        identity["cpes"] = values
    if "osv" in profile:
        osv = profile["osv"]
        if not isinstance(osv, dict) or not all(
            isinstance(osv.get(key), str) and osv[key].strip()
            for key in ("ecosystem", "name")
        ) or ("version" in osv and (not isinstance(osv["version"], str) or not osv["version"])):
            raise ValueError("TVP security OSV identity must declare an ecosystem and package name")
        identity["osv"] = dict(osv)
    return identity


def components(selected):
    """Scan a derivation/output once while retaining its aliases and use sites."""
    grouped = {}
    for package in selected["packages"]:
        key = (package["drvPath"], package["outputName"])
        profile = package.get("security")
        identity = package_identity(profile, package["version"])
        if key not in grouped:
            digest = hashlib.sha256(json.dumps(key).encode()).hexdigest()
            grouped[key] = {
                "id": f"tvp-{digest}",
                "name": package["pname"],
                "version": package["version"],
                "drvPath": package["drvPath"],
                "outputName": package["outputName"],
                "identity": identity,
                "selections": [],
            }
        component = grouped[key]
        if (component["name"], component["version"], component["identity"]) != (
            package["pname"], package["version"], identity,
        ):
            raise ValueError("Conflicting TVP security identities for the same derivation output")
        selection = {key: package[key] for key in ("namespace", "selector", "kind", "usedBy")}
        if selection not in component["selections"]:
            component["selections"].append(selection)
    return list(grouped.values())


def audit(selected, backend, *, offline=False, cache_dir=None):
    if backend not in ("grype", "osv"):
        raise ValueError("Choose an experimental audit backend: grype or osv")
    resolved = components(selected)
    provider = importlib.import_module(f"audit_{backend}")
    result = provider.scan(resolved, offline=offline, cache_dir=cache_dir)
    if (not isinstance(result, dict) or not isinstance(result.get("backend"), dict)
            or result["backend"].get("name") != backend or not isinstance(result.get("database"), dict)
            or not result["database"]):
        raise ValueError("Audit backend returned incomplete scanner/database evidence")
    rows = result.get("results")
    if not isinstance(rows, list):
        raise ValueError("Audit backend returned invalid component results")
    expected = {component["id"] for component in resolved}
    observed = set()
    by_id = {}
    findings = []
    for row in rows:
        if (not isinstance(row, dict) or not isinstance(row.get("component"), str)
                or row["component"] not in expected or row["component"] in observed):
            raise ValueError("Audit backend returned an unknown or duplicate component")
        observed.add(row["component"])
        if row.get("status") not in ("scanned", "unsupported") or not isinstance(row.get("vulnerabilities"), list):
            raise ValueError("Audit backend returned invalid coverage")
        if row["status"] == "unsupported" and (not row.get("reason") or row["vulnerabilities"]):
            raise ValueError("Unsupported audit components require a reason and no findings")
        by_id[row["component"]] = row
        seen = set()
        for finding in row["vulnerabilities"]:
            if not isinstance(finding, dict) or not isinstance(finding.get("id"), str) or not finding["id"]:
                raise ValueError("Audit backend returned an invalid advisory")
            if finding.get("severity") not in SEVERITIES:
                raise ValueError("Audit backend returned an invalid advisory severity")
            evidence = (finding["id"], finding.get("namespace"), finding.get("match"))
            if evidence in seen:
                raise ValueError("Audit backend returned a duplicate advisory for one component")
            seen.add(evidence)
            findings.append({**finding, "component": row["component"], "applicability": "unassessed"})
    if observed != expected:
        raise ValueError("Audit backend omitted components; refusing an incomplete result")
    for component in resolved:
        row = by_id[component["id"]]
        component["status"] = row["status"]
        if "reason" in row:
            component["reason"] = row["reason"]
    counts = Counter(component["status"] for component in resolved)
    report = {
        "schema": 1,
        "attribute": selected["attribute"],
        "input": selected["input"],
        "scope": {"inventory": selected["scope"], "excluded": EXCLUDED_SCOPES, "environmentComplete": False},
        "backend": result["backend"],
        "database": result["database"],
        "coverage": {
            "total": len(resolved), "scanned": counts["scanned"], "unsupported": counts["unsupported"],
            "completeForInventory": bool(resolved) and counts["unsupported"] == 0
                and selected.get("outputCoverage", {}).get("complete", True),
        },
        "components": resolved,
        "findings": findings,
    }
    for field in ("system", "outputs", "skippedOutputs", "outputCoverage"):
        if field in selected:
            report[field] = selected[field]
    return report


def format_prioritization(finding):
    """Describe upstream threat signals without assessing application exposure."""
    lines = []
    for record in finding.get("knownExploited", []):
        details = [f'CISA KEV: {record["cve"]} listed']
        if record.get("dateAdded"):
            details.append(f'added {record["dateAdded"]}')
        if record.get("knownRansomwareCampaignUse"):
            details.append(f'ransomware use: {record["knownRansomwareCampaignUse"]}')
        lines.append("; ".join(details))
    for record in finding.get("epss", []):
        details = [f'EPSS {record["cve"]}: {record["epss"]:.2%}']
        if "percentile" in record:
            details.append(f'percentile {record["percentile"] * 100:.2f}')
        if record.get("date"):
            details.append(f'scored {record["date"]}')
        lines.append("; ".join(details))
    if "risk" in finding:
        risk = finding["risk"]
        lines.append(f'{risk["source"].capitalize()} risk: {risk["score"]:g}/100 (scanner prioritization)')
    return lines


def format_audit(result):
    source = result["input"]["locked"]
    revision = source.get("rev") or source.get("narHash") or "unknown revision"
    coverage = result["coverage"]
    version = result["backend"].get("version") or "not invoked"
    scope = format_output_scope(result)
    lines = [scope[0], f'{result["input"]["name"]}  {revision}',
             f'Scanner: {result["backend"]["name"]} ({version})',
             f'Coverage: {coverage["scanned"]}/{coverage["total"]} TVP components scanned; {coverage["unsupported"]} unsupported.']
    lines.extend(scope[1:])
    database = result["database"]
    if not coverage["scanned"]:
        lines.append("Advisory data: not queried.")
    elif database.get("kind") == "query-responses":
        freshness = "stale" if database.get("stale") else "within cache freshness limit"
        mode = "offline" if database.get("offline") else "online/cache"
        lines.append(f'Advisory data: OSV responses, oldest {database.get("oldestResponseAt", "unknown")}; {freshness}; {mode}.')
    else:
        descriptor = database.get("descriptor", {})
        mode = "offline" if database.get("offline") else "update checked"
        lines.append(f'Advisory data: database built {descriptor.get("built", "unknown")}; {mode}.')
    for name, label in (("kev", "CISA KEV"), ("epss", "EPSS")):
        provider = database.get("providers", {}).get(name, {})
        if provider.get("captured"):
            lines.append(f'{label} data captured: {provider["captured"]}.')
    findings = {}
    for finding in result["findings"]:
        findings.setdefault(finding["component"], []).append(finding)
    for component in result["components"]:
        matches = findings.get(component["id"], [])
        if component["status"] == "unsupported":
            lines.append(f'  {component["name"]} {component["version"]}: not scanned — {component["reason"]}')
        elif matches:
            lines.append(f'  {component["name"]} {component["version"]}')
            origins = sorted({usage["attribute"] for selection in component.get("selections", [])
                              for usage in selection.get("usedBy", []) if "attribute" in usage})
            if origins:
                lines.append("    Outputs: " + ", ".join(origins))
            for finding in matches:
                fixes = ", ".join(finding.get("fixedVersions", [])) or "not supplied"
                lines.append(f'    {finding["severity"].upper()} {finding["id"]} — applicability unassessed; upstream fixes: {fixes}')
                if finding.get("url"):
                    lines.append(f'      {finding["url"]}')
                lines.extend(f"      {line}" for line in format_prioritization(finding))
    if not coverage["scanned"]:
        lines.append("No components were scanned; this is not a clean security result.")
    elif not result["findings"]:
        lines.append("No advisory matches among the scanned components.")
    if any(any(field in finding for field in ("knownExploited", "epss", "risk"))
           for finding in result["findings"]):
        lines.append("Prioritization: KEV records known exploitation; EPSS forecasts global exploitation activity over the next 30 days. Missing threat data is unknown. These signals do not assess application exposure or change severity gates.")
    lines.append("Scope: declared TVP selections only. Transitive dependencies, language locks, non-TVP packages and application reachability are not assessed.")
    return "\n".join(lines)


def exit_status(result, *, fail_on=None, require_coverage=False):
    if not result.get("outputCoverage", {}).get("complete", True):
        return 1
    if require_coverage and not result["coverage"]["completeForInventory"]:
        return 3
    if fail_on is not None and any(
        SEVERITIES.index(finding["severity"]) >= SEVERITIES.index(fail_on)
        for finding in result["findings"]
    ):
        return 2
    return 0

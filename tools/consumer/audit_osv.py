"""Experimental OSV adapter over explicitly declared upstream identities.

The cache contains responses to exact package/version queries, not an OSV
database snapshot. See https://google.github.io/osv.dev/post-v1-querybatch/.
"""

from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import tempfile
from urllib.parse import quote
from urllib.request import Request, urlopen


API = "https://api.osv.dev/v1"
MAX_AGE = 24 * 60 * 60
MAX_RESPONSE = 32 * 1024 * 1024


def _canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":")).encode()


def _request(path, payload=None):
    data = None if payload is None else _canonical(payload)
    request = Request(API + path, data=data, headers={
        "Accept": "application/json", "Content-Type": "application/json",
        "User-Agent": "tvp-audit/osv-v1",
    })
    with urlopen(request, timeout=30) as response:
        body = response.read(MAX_RESPONSE + 1)
    if len(body) > MAX_RESPONSE:
        raise ValueError("OSV response exceeds the supported size")
    result = json.loads(body)
    if not isinstance(result, dict) or "error" in result:
        raise ValueError("OSV returned an invalid response")
    return result


def _timestamp(value):
    if not isinstance(value, str):
        raise ValueError("Invalid OSV cache timestamp")
    stamp = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if stamp.tzinfo is None:
        raise ValueError("OSV cache timestamp must include its timezone")
    return stamp.timestamp()


def _query(component):
    declared = component.get("identity", {})
    if not isinstance(declared, dict):
        raise ValueError(f"Invalid upstream identity for {component['id']}")
    identity = declared.get("osv")
    if identity is None:
        return None, "No OSV ecosystem identity is declared"
    if not isinstance(identity, dict) or any(
        not isinstance(identity.get(field), str) or not identity[field].strip()
        for field in ("name", "ecosystem")
    ):
        raise ValueError(f"Invalid OSV identity for {component['id']}")
    version = component.get("version")
    if not isinstance(version, str) or not version.strip():
        return None, "Package version is unavailable"
    query_version = identity.get("version", version)
    if not isinstance(query_version, str) or not query_version.strip():
        raise ValueError(f"Invalid OSV query version for {component['id']}")
    return {
        "package": {field: identity[field] for field in ("name", "ecosystem")},
        "version": query_version,
    }, None


def _records(records):
    if not isinstance(records, list):
        raise ValueError("OSV advisory records must be a list")
    for record in records:
        if not isinstance(record, dict) or not isinstance(record.get("id"), str) or not record["id"]:
            raise ValueError("OSV returned an advisory without an ID")
    return records


def _fetch(queries):
    """Finish all batch pages and details before any result can be cached."""
    references = {key: set() for key in queries}
    pending = list(queries.items())
    seen_pages = set()
    while pending:
        following = []
        for start in range(0, len(pending), 100):
            chunk = pending[start:start + 100]
            response = _request("/querybatch", {"queries": [query for _, query in chunk]})
            results = response.get("results")
            if not isinstance(results, list) or len(results) != len(chunk):
                raise ValueError("OSV batch response does not match the requested queries")
            for (key, query), result in zip(chunk, results):
                if not isinstance(result, dict) or any(field in result for field in ("error", "code", "message")):
                    raise ValueError("OSV returned an invalid batch result")
                for record in _records(result.get("vulns", [])):
                    references[key].add(record["id"])
                token = result.get("next_page_token")
                if token is not None and not isinstance(token, str):
                    raise ValueError("OSV returned an invalid page token")
                if token:
                    if (key, token) in seen_pages or len(seen_pages) >= 10000:
                        raise ValueError("OSV pagination did not complete")
                    seen_pages.add((key, token))
                    following.append((key, {**queries[key], "page_token": token}))
        pending = following
    details = {}
    for advisory_id in sorted(set().union(*references.values())):
        record = _request("/vulns/" + quote(advisory_id, safe=""))
        _records([record])
        if record["id"] != advisory_id:
            raise ValueError("OSV advisory ID differs from its batch reference")
        details[advisory_id] = record
    return {key: [details[item] for item in sorted(ids)] for key, ids in references.items()}


def _cache_read(path, query, now):
    try:
        entry = json.loads(path.read_text())
    except FileNotFoundError:
        return None
    if (not isinstance(entry, dict) or entry.get("schema") != 1 or entry.get("query") != query
            or not isinstance(entry.get("sha256"), str)):
        raise ValueError(f"Invalid OSV cache entry: {path.name}")
    records = _records(entry.get("records"))
    if hashlib.sha256(_canonical(records)).hexdigest() != entry["sha256"]:
        raise ValueError(f"OSV cache content digest differs: {path.name}")
    for record in records:
        _vulnerability(record, query)
    age = now - _timestamp(entry.get("retrievedAt"))
    if age < -300:
        raise ValueError("OSV cache timestamp is in the future")
    return entry


def _cache_write(path, entry):
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as stream:
            temporary = Path(stream.name)
            json.dump(entry, stream, sort_keys=True)
            stream.write("\n")
        os.replace(temporary, path)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def _vulnerability(record, query):
    aliases = record.get("aliases", [])
    affected = record.get("affected", [])
    references = record.get("references", [])
    if (not isinstance(aliases, list) or any(not isinstance(value, str) for value in aliases)
            or not isinstance(affected, list) or any(not isinstance(value, dict) for value in affected)
            or not isinstance(references, list) or any(not isinstance(value, dict) for value in references)):
        raise ValueError(f"Invalid OSV advisory data: {record['id']}")
    summary = record.get("summary", "")
    if not isinstance(summary, str):
        raise ValueError(f"Invalid OSV summary: {record['id']}")
    if record.get("withdrawn") is not None and not isinstance(record["withdrawn"], str):
        raise ValueError(f"Invalid OSV withdrawal metadata: {record['id']}")
    database = record.get("database_specific", {})
    if not isinstance(database, dict):
        raise ValueError(f"Invalid OSV database metadata: {record['id']}")
    severities = [database.get("severity")]
    fixed = set()
    for item in affected:
        package = item.get("package", {})
        ranges = item.get("ranges", [])
        if not isinstance(package, dict) or not isinstance(ranges, list) or any(not isinstance(value, dict) for value in ranges):
            raise ValueError(f"Invalid OSV affected package/ranges: {record['id']}")
        package_matches = all(package.get(k) == v for k, v in query["package"].items())
        repository_matches = query["package"]["ecosystem"] == "GIT" and any(
            interval.get("type") == "GIT" and interval.get("repo") == query["package"]["name"]
            for interval in ranges
        )
        if not (package_matches or repository_matches):
            continue
        ecosystem = item.get("ecosystem_specific", {})
        if not isinstance(ecosystem, dict):
            raise ValueError(f"Invalid OSV ecosystem metadata: {record['id']}")
        severities.append(ecosystem.get("severity"))
        for interval in ranges:
            events = interval.get("events", [])
            if not isinstance(events, list) or any(not isinstance(event, dict) for event in events):
                raise ValueError(f"Invalid OSV range events: {record['id']}")
            if interval.get("type") == "GIT":
                continue  # Fixed commits are not fixed release versions.
            for event in events:
                if "fixed" in event:
                    if not isinstance(event["fixed"], str) or not event["fixed"]:
                        raise ValueError(f"Invalid OSV fixed version: {record['id']}")
                    fixed.add(event["fixed"])
    rank = {name: index for index, name in enumerate(("unknown", "negligible", "low", "medium", "high", "critical"))}
    labels = [str(value).lower() for value in severities if isinstance(value, str)]
    labels = ["medium" if value == "moderate" else value for value in labels]
    severity = max((value for value in labels if value in rank), key=rank.get, default="unknown")
    url = next((item.get("url") for item in references if item.get("type") == "ADVISORY"
                and isinstance(item.get("url"), str) and item["url"].startswith("https://")), None)
    return {
        "id": record["id"], "aliases": sorted(set(aliases)), "summary": summary,
        "severity": severity, "url": url or "https://osv.dev/vulnerability/" + quote(record["id"], safe=""),
        "fixedVersions": sorted(fixed), "match": "osv-ecosystem-version",
    }


def scan(components, *, offline=False, cache_dir=None):
    cache = Path(cache_dir) if cache_dir is not None else (
        Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "tvp/audit/osv"
    )
    now = datetime.now(timezone.utc)
    queries, selected = {}, []
    for component in components:
        query, reason = _query(component)
        key = hashlib.sha256(_canonical(query)).hexdigest() if query is not None else None
        selected.append((component["id"], key, reason))
        if key is not None:
            queries[key] = query
    entries, missing = {}, {}
    cached = 0
    for key, query in queries.items():
        entry = _cache_read(cache / (key + ".json"), query, now.timestamp())
        if entry is not None and (offline or now.timestamp() - _timestamp(entry["retrievedAt"]) <= MAX_AGE):
            entries[key] = entry
            cached += 1
        elif offline:
            raise RuntimeError("OSV offline mode needs a cached response for every mapped package/version")
        else:
            missing[key] = query
    if missing:
        records = _fetch(missing)
        for key, query in missing.items():
            # Validate full details before storing them as a reusable complete query.
            for record in records[key]:
                _vulnerability(record, query)
            entry = {
                "schema": 1, "query": query, "retrievedAt": now.isoformat(), "records": records[key],
                "sha256": hashlib.sha256(_canonical(records[key])).hexdigest(),
            }
            _cache_write(cache / (key + ".json"), entry)
            entries[key] = entry
    results = []
    for component_id, key, reason in selected:
        results.append({"component": component_id, "status": "unsupported", "reason": reason,
                        "vulnerabilities": []} if key is None else {
            "component": component_id, "status": "scanned", "vulnerabilities": [
                _vulnerability(record, queries[key]) for record in entries[key]["records"]
                if not record.get("withdrawn")
            ],
        })
    stamps = [entry["retrievedAt"] for entry in entries.values()]
    age = max((max(0, now.timestamp() - _timestamp(value)) for value in stamps), default=0)
    return {
        "backend": {"name": "osv", "version": "v1"},
        "database": {
            "kind": "query-responses", "source": API, "offline": offline,
            "oldestResponseAt": min(stamps, key=_timestamp) if stamps else None,
            "newestResponseAt": max(stamps, key=_timestamp) if stamps else None,
            "maxAgeSeconds": int(age), "stale": age > MAX_AGE,
            "cachedQueries": cached, "queries": len(queries),
            "sha256": hashlib.sha256(_canonical({key: value["sha256"] for key, value in entries.items()})).hexdigest(),
        },
        "results": results,
    }

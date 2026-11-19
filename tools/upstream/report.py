"""Produce the structured upstream report used for maintenance discovery."""

import json
import re
import sys
from urllib.parse import urlsplit, urlunsplit


STABLE = re.compile(r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)")
PRERELEASE = re.compile(
    r"[0-9]+(?:\.[0-9]+)+[-+._]?(?:alpha|beta|rc|preview|pre|dev|a|b)[._-]?[0-9]*",
    re.IGNORECASE,
)


def version_number(version):
    match = STABLE.fullmatch(version)
    return tuple(map(int, match.groups())) if match else None


def public_url(value):
    if value is None:
        return None
    try:
        parts = urlsplit(value)
    except ValueError:
        return None
    if parts.scheme not in ("https", "http") or not parts.netloc or "@" in parts.netloc:
        return None
    return urlunsplit((parts.scheme, parts.netloc, parts.path, "", ""))


def coverage_for(coverage, selector, family):
    if selector and coverage is None:
        raise ValueError(f"--php requires a PHP extension family ({family})")
    if coverage is None:
        return None
    rows = [
        {**row, "source": public_url(row.get("source"))}
        for row in coverage["rows"]
        if not selector or row["php"] == selector or row["php"].startswith(selector + ".")
    ]
    if selector and not rows:
        raise ValueError(f"no declared PHP version matches {selector} ({family})")
    return {"kind": coverage["kind"], "rows": rows}


def release(kind, version, status, reason=None):
    row = {"kind": kind, "version": version, "status": status}
    if reason is not None:
        row["reason"] = reason
    return row


def commit_rows(upstream, head):
    revisions = set(upstream["revisions"].values())
    rows = [release("commit", version, "packaged") for version in sorted(revisions)]
    if head is not None and head["missingRevision"] is not None:
        rows.append(release("commit", head["missingRevision"], "candidate"))
    return rows


def release_rows(packaged, listing, unavailable, php):
    if listing is None:
        return [release("release", version, "packaged") for version in sorted(packaged)]

    # One numeric maintenance line is one major/minor pair. A missing patch
    # counts as an update only if it advances an already packaged stable line.
    latest_by_series = {}
    for version in packaged:
        number = version_number(version)
        if number is not None:
            series = number[:2]
            latest_by_series[series] = max(number, latest_by_series.get(series, number))
    latest_stable = max(latest_by_series.values(), default=None)

    included = set(listing["included"])
    excluded = {version for version in listing["excluded"] if re.match(r"[0-9]", version)}
    rows = []
    for version in sorted(set(packaged) | included | excluded | unavailable.keys()):
        number = version_number(version)
        if version in packaged:
            status, reason = "packaged", None
        elif version in unavailable:
            status, reason = "unavailable", unavailable[version]
        elif PRERELEASE.fullmatch(version):
            status, reason = "prerelease", None
        elif version not in included:
            status, reason = "unsupported", "Excluded by the source release policy."
        elif php:
            status, reason = "unknown-compatibility", "PHP requirements are not recorded."
        elif number is None:
            status, reason = "unsupported", "Version needs a family-specific update policy."
        elif number[:2] in latest_by_series:
            status = "candidate" if number > latest_by_series[number[:2]] else "historical-gap"
            reason = None
        elif latest_stable is not None and number < latest_stable:
            status, reason = "historical-gap", None
        else:
            status, reason = "unsupported", "No stable version in this series is packaged."
        rows.append(release("release", version, status, reason))
    return rows


def describe(observation, selector):
    row = observation["row"]
    upstream = row["upstream"]
    family = row["pname"]
    coverage = coverage_for(row["php"], selector, family)
    source = None
    if upstream is not None:
        source = {
            "type": upstream["type"],
            "url": public_url(upstream.get("url")),
            "scope": upstream.get("scope"),
        }

    if upstream is not None and upstream["type"] == "git-head":
        releases = commit_rows(upstream, observation["head"])
    else:
        unavailable = {
            version: entry["reason"]
            for entry in (upstream or {}).get("unavailable", [])
            for version in entry["versions"]
        }
        releases = release_rows(set(row["versions"]), observation["listing"], unavailable, coverage is not None)

    result = {
        "family": family,
        "discoveryStatus": observation["status"],
        "source": source,
        "releases": releases,
        "php": coverage,
    }
    if observation["error"]:
        result["error"] = observation["error"]
    return result


def main(revision, selector):
    families = [describe(json.loads(line), selector) for line in sys.stdin]
    print(json.dumps({"schemaVersion": 1, "revision": revision or None, "families": families}))


if __name__ == "__main__":
    try:
        main(*sys.argv[1:])
    except ValueError as error:
        print(f"tvp-upstream: {error}", file=sys.stderr)
        sys.exit(2)

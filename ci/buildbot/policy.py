"""Admission and reporting policy; never run candidate code on the controller."""
import re

SHA = re.compile(r"[0-9a-f]{40}")
REPOSITORY = re.compile(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+")
STATUS_CONTEXT = "tvp/smoke"


def eligible(pr, repository):
    """Test every open repository PR, including drafts and stacked branches."""
    head, base = pr.get("head") or {}, pr.get("base") or {}
    target = base.get("ref")
    head_sha, base_sha = head.get("sha"), base.get("sha")
    return (
        pr.get("state") == "open"
        and isinstance(target, str) and bool(target)
        and (base.get("repo") or {}).get("full_name") == repository
        and (head.get("repo") or {}).get("full_name") == repository
        and isinstance(head_sha, str) and bool(SHA.fullmatch(head_sha))
        and isinstance(base_sha, str) and bool(SHA.fullmatch(base_sha))
    )


def summary(status):
    counts = status.get("counts", {})
    tests = status.get("testCounts", {})
    failed = sorted(name for name, job in status.get("jobs", {}).items()
                    if job.get("status") == "failed-or-blocked")
    text = (f"{counts.get('passed', 0)}/{sum(counts.values())} suites; "
            f"{tests.get('passed', 0)}/{sum(tests.values())} tests")
    if status.get("validationScope"):
        text = status["validationScope"] + ": " + text
    if failed:
        text += "; failed: " + ", ".join(failed)
    elif status.get("phase") != "passed":
        text += "; " + status.get("error", status.get("phase", "unknown"))
    return text[:140]


def result_properties(rc, stdout, stderr):
    """Only the final structured record supplies the UI summary; rc still wins."""
    import json
    records = [line[len("TVP_CI_RESULT="):] for line in stdout.splitlines()
               if line.startswith("TVP_CI_RESULT=")]
    if not records:
        return {"ci_summary": "Validation interrupted before a final result"}
    try:
        result = json.loads(records[-1])
        text = summary(result)
        if rc and result.get("phase") == "passed":
            text = "Validation process failed after reporting a pass"
        return {"ci_summary": text}
    except (ValueError, TypeError, AttributeError):
        return {"ci_summary": "Invalid final validation report"}

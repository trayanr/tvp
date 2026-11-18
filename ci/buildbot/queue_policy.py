"""Supersede queued automatic requests for the same PR and target."""

from twisted.internet import defer

from policy import SHA


CATALOGUE = "catalogue"
CATALOGUE_REASON = "The AnyBranchScheduler scheduler named 'catalogue' triggered this build"


@defer.inlineCallbacks
def automatic_pr(master, request):
    buildset_id = request["buildsetid"]
    buildset = yield master.data.get(("buildsets", buildset_id))
    # Buildbot's manual Rebuild copies the original scheduler and PR properties.
    if buildset["reason"] != CATALOGUE_REASON or len(buildset["sourcestamps"]) != 1:
        return None
    properties = yield master.db.buildsets.getBuildsetProperties(buildset_id)
    if properties.get("scheduler") != (CATALOGUE, "Scheduler"):
        return None
    number = properties.get("tvp_pr", (None,))[0]
    target = properties.get("tvp_target_branch", (None,))[0]
    base = properties.get("tvp_base", ("",))[0]
    stamp, = buildset["sourcestamps"]
    head = stamp["revision"]
    if (type(number) is not int or number < 1 or not isinstance(target, str) or not target
            or not isinstance(base, str) or not SHA.fullmatch(base)
            or not isinstance(head, str) or not SHA.fullmatch(head)
            or stamp["branch"] != f"refs/pull/{number}/head" or stamp["patch"] is not None):
        return None
    return (stamp["repository"], stamp["project"], number, target), (head, base)


@defer.inlineCallbacks
def supersedes_queued_pr(master, _builder, new, old):
    # Buildbot claims an older request before marking it skipped. A worker that
    # claims it first retains ownership and runs to completion.
    if (new["buildrequestid"] <= old["buildrequestid"]
            or old["complete"] or old["claimed"] or old["waited_for"]):
        return False
    successor = yield automatic_pr(master, new)
    if successor is None:
        return False
    predecessor = yield automatic_pr(master, old)
    return (predecessor is not None and successor[0] == predecessor[0]
            and successor[1] != predecessor[1])

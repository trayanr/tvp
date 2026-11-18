from pathlib import Path
import sys
from types import SimpleNamespace
from unittest.mock import Mock

from buildbot.process.buildrequest import BuildRequestCollapser
from buildbot.process.results import SKIPPED
from twisted.internet import defer
from twisted.trial.unittest import TestCase

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from queue_policy import CATALOGUE_REASON, supersedes_queued_pr


def request(number, **overrides):
    return {"buildrequestid": number, "buildsetid": number, "builderid": 1,
            "submitted_at": number, "complete": False, "claimed": False,
            "waited_for": False} | overrides


def buildset(head, pr=204, target="master", base="a" * 40, reason=CATALOGUE_REASON):
    stamp = {"repository": "https://github.com/trayanr/tvp.git", "project": "trayanr/tvp",
             "branch": f"refs/pull/{pr}/head" if pr else "master",
             "revision": head, "patch": None}
    properties = {"scheduler": ("catalogue", "Scheduler")}
    if pr is not None:
        properties.update(tvp_pr=(pr, "Change"), tvp_base=(base, "Change"),
                          tvp_target_branch=(target, "Change"))
    return {"reason": reason, "sourcestamps": [stamp]}, properties


def queue(requests, buildsets, losing_claim=None):
    def get(path, filters=None):
        if path[0] == "builders":
            if len(path) == 2:
                return defer.succeed({"name": "tvp-full"})
            return defer.succeed([r for r in requests.values() if not r["claimed"]])
        if path[0] == "buildrequests":
            return defer.succeed(requests[path[1]])
        return defer.succeed(buildsets[path[1]][0])

    builder = SimpleNamespace(getCollapseRequestsFn=lambda: supersedes_queued_pr)
    updates = SimpleNamespace(
        claimBuildRequests=Mock(side_effect=lambda ids: defer.succeed(ids != [losing_claim])),
        completeBuildRequests=Mock(return_value=defer.succeed(True)),
    )
    return SimpleNamespace(
        data=SimpleNamespace(get=get, updates=updates),
        db=SimpleNamespace(buildsets=SimpleNamespace(
            getBuildsetProperties=lambda bsid: defer.succeed(buildsets[bsid][1]))),
        botmaster=SimpleNamespace(builders={"tvp-full": builder}),
    )


class Supersession(TestCase):
    @defer.inlineCallbacks
    def test_only_an_older_pending_automatic_revision_is_skipped(self):
        old, current = "b" * 40, "c" * 40
        rows = {
            1: buildset(old),
            2: buildset(old, pr=None),
            3: buildset(old, pr=205),
            4: buildset(old, target="release"),
            5: buildset(old, reason="rebuild"),
            6: buildset(old, reason="manual"),
            7: buildset(old),
            8: buildset(current),
            9: buildset(current),
            10: buildset(old),
        }
        requests = {number: request(number) for number in rows}
        requests[7]["claimed"] = True
        master = queue(requests, rows)
        self.assertEqual((yield BuildRequestCollapser(master, [9]).collapse()), [1])
        master.data.updates.completeBuildRequests.assert_called_once_with([1], SKIPPED)

    @defer.inlineCallbacks
    def test_new_base_can_supersede_same_head_but_worker_claim_wins(self):
        head = "b" * 40
        master = queue(
            {1: request(1), 2: request(2)},
            {1: buildset(head), 2: buildset(head, base="c" * 40)},
            losing_claim=1,
        )
        self.assertEqual((yield BuildRequestCollapser(master, [2]).collapse()), [])
        master.data.updates.claimBuildRequests.assert_called_once_with([1])
        master.data.updates.completeBuildRequests.assert_not_called()

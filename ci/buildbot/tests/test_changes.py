"""Exercise delivery and restart boundaries, with no GitHub or database access."""
from pathlib import Path
from types import SimpleNamespace
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from twisted.internet import defer
from twisted.trial.unittest import TestCase
from changes import LabelledPullRequests
from policy import eligible


def pull(number=1):
    return {"number": number, "state": "open", "draft": False, "labels": [{"name": "ci:build"}],
            "head": {"sha": "a" * 40, "repo": {"full_name": "trayanr/tvp"}},
            "base": {"sha": "b" * 40, "ref": "master", "repo": {"full_name": "trayanr/tvp"}},
            "user": {"login": "trayanr"}, "title": "Expand PHP", "html_url": "https://github.com/trayanr/tvp/pull/1"}


def source(state, emitted, fail=False):
    def emit(**change):
        if fail:
            raise RuntimeError("temporary DB failure")
        emitted.append(change)
        return defer.succeed(None)
    return SimpleNamespace(
        owner="trayanr", repo="tvp", pullrequest_filter=lambda pr: eligible(pr, "trayanr/tvp"),
        _getCurrentRev=lambda number: defer.succeed(state.get(number)),
        _setCurrentRev=lambda number, revision: state.update({number: revision}),
        master=SimpleNamespace(data=SimpleNamespace(updates=SimpleNamespace(addChange=emit))),
    )


class Delivery(TestCase):
    @defer.inlineCallbacks
    def test_restart_and_repeated_polls_do_not_repeat_builds(self):
        state, emitted = {}, []
        yield LabelledPullRequests._processChanges(source(state, emitted), [pull()])
        yield LabelledPullRequests._processChanges(source(state, emitted), [pull()])
        self.assertEqual(len(emitted), 1)
        self.assertEqual(emitted[0]["revision"], "a" * 40)

    @defer.inlineCallbacks
    def test_new_head_or_base_requeues_even_when_short_sha_matches(self):
        state, emitted = {}, []
        pr = pull()
        yield LabelledPullRequests._processChanges(source(state, emitted), [pr])
        pr["head"]["sha"] = "a" * 39 + "c"
        yield LabelledPullRequests._processChanges(source(state, emitted), [pr])
        pr["base"]["sha"] = "d" * 40
        yield LabelledPullRequests._processChanges(source(state, emitted), [pr])
        self.assertEqual(len(emitted), 3)
        self.assertEqual(emitted[-1]["properties"]["tvp_base"], "d" * 40)

    @defer.inlineCallbacks
    def test_unlabelled_then_labelled_same_head_is_delivered(self):
        state, emitted = {}, []
        pr = pull(); pr["labels"] = []
        yield LabelledPullRequests._processChanges(source(state, emitted), [pr])
        self.assertEqual(state, {})
        pr["labels"] = [{"name": "ci:build"}]
        yield LabelledPullRequests._processChanges(source(state, emitted), [pr])
        self.assertEqual(len(emitted), 1)

    @defer.inlineCallbacks
    def test_failed_delivery_is_retried_after_restart(self):
        state, emitted = {}, []
        yield self.assertFailure(LabelledPullRequests._processChanges(source(state, emitted, fail=True), [pull()]), RuntimeError)
        self.assertEqual(state, {})
        yield LabelledPullRequests._processChanges(source(state, emitted), [pull()])
        self.assertEqual(len(emitted), 1)

    @defer.inlineCallbacks
    def test_more_than_one_api_page_is_queued_oldest_first(self):
        calls = []
        def get(path):
            calls.append(path)
            batch = [pull(n) for n in range(101, 1, -1)] if len(calls) == 1 else [pull(1)]
            return defer.succeed(SimpleNamespace(code=200, json=lambda: defer.succeed(batch)))
        pulls = yield LabelledPullRequests._getPulls(SimpleNamespace(owner="trayanr", repo="tvp", _http=SimpleNamespace(get=get)))
        self.assertEqual([pr["number"] for pr in pulls], list(range(1, 102)))
        self.assertEqual(len(calls), 2)
        self.assertIn("page=2", calls[-1])

    @defer.inlineCallbacks
    def test_http_failure_is_not_an_empty_successful_poll(self):
        response = SimpleNamespace(code=503)
        result = LabelledPullRequests._getPulls(SimpleNamespace(owner="trayanr", repo="tvp", _http=SimpleNamespace(get=lambda _: defer.succeed(response))))
        yield self.assertFailure(result, RuntimeError)

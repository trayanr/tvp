"""HTTP admission and durable delivery boundaries, without GitHub or a database."""
from copy import deepcopy
from pathlib import Path
from types import SimpleNamespace
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from twisted.internet import defer
from twisted.trial.unittest import TestCase
from changes import LabelledPullRequests
from policy import eligible


HEAD, OLD_BASE, BASE, NEXT_BASE = (c * 40 for c in 'abcd')


def pull(number=1, branch='master'):
    return {"number": number, "state": "open", "draft": False, "labels": [{"name": "ci:build"}],
            "head": {"sha": HEAD, "repo": {"full_name": "trayanr/tvp"}},
            "base": {"sha": OLD_BASE, "ref": branch, "repo": {"full_name": "trayanr/tvp"}},
            "user": {"login": "trayanr"}, "title": "Expand PHP", "html_url": "https://github.com/trayanr/tvp/pull/1"}


def response(code, body):
    def json():
        if isinstance(body, Exception):
            return defer.fail(body)
        return defer.succeed(deepcopy(body))
    return defer.succeed(SimpleNamespace(code=code, json=json))


class HTTP:
    def __init__(self, base=BASE, ancestry='ahead'):
        self.base, self.ancestry = base, ancestry
        self.calls = []
        self.failures = {}

    def request(self, method, path, **kwargs):
        self.calls.append((method, path, kwargs))
        kind = 'ref' if '/git/ref/' in path else 'compare' if '/compare/' in path else 'status'
        if kind in self.failures:
            return response(*self.failures[kind])
        if kind == 'ref':
            return response(200, {'ref': 'refs/heads/' + path.split('/heads/')[1].replace('%2F', '/'),
                                  'object': {'sha': self.base, 'type': 'commit'}})
        if kind == 'compare':
            return response(200, {'status': self.ancestry, 'base_commit': {'sha': self.base},
                                  'merge_base_commit': {'sha': self.base if self.ancestry in ['ahead', 'identical'] else OLD_BASE}})
        return response(201, kwargs['json'])

    def get(self, path):
        return self.request('GET', path)

    def post(self, path, **kwargs):
        return self.request('POST', path, **kwargs)


def source(state, emitted, http, fail=False, branch='master'):
    def emit(**change):
        if fail:
            raise RuntimeError("temporary DB failure")
        emitted.append(change)
        return defer.succeed(None)
    return SimpleNamespace(
        owner="trayanr", repo="tvp", _http=http,
        pullrequest_filter=lambda pr: eligible(pr, "trayanr/tvp", branch=branch),
        _getCurrentRev=lambda number: defer.succeed(deepcopy(state.get(number))),
        _setCurrentRev=lambda number, revision: state.update({number: deepcopy(revision)}),
        master=SimpleNamespace(data=SimpleNamespace(updates=SimpleNamespace(addChange=emit))),
    )


def poll(state, emitted, http, pulls=None, **kwargs):
    return LabelledPullRequests._processChanges(source(state, emitted, http, **kwargs), [pull()] if pulls is None else pulls)


class Delivery(TestCase):
    @defer.inlineCallbacks
    def test_restart_and_repeated_polls_do_not_repeat_builds(self):
        state, emitted, http = {}, [], HTTP()
        yield poll(state, emitted, http)
        yield poll(state, emitted, http)
        self.assertEqual(len(emitted), 1)
        self.assertEqual(emitted[0]['revision'], HEAD)
        self.assertEqual(emitted[0]['properties']['tvp_base'], BASE)
        self.assertEqual(sum('/git/ref/' in path for _, path, _ in http.calls), 2)

    @defer.inlineCallbacks
    def test_stale_payload_target_advance_blocks_then_author_update_admits(self):
        state, emitted, http, pr = {}, [], HTTP(), pull()
        yield poll(state, emitted, http, [pr])
        http.base, http.ancestry = NEXT_BASE, 'diverged'
        yield poll(state, emitted, http, [pr])
        # Reconstructed source shares only durable state, as after a restart.
        yield poll(state, emitted, http, [pr])
        self.assertEqual(len(emitted), 1)
        statuses = [kwargs['json'] for method, _, kwargs in http.calls if method == 'POST']
        self.assertEqual(len(statuses), 1)
        self.assertEqual(statuses[0]['state'], 'pending')
        self.assertEqual(statuses[0]['context'], 'tvp/full')
        self.assertIn('Rebase or merge', statuses[0]['description'])
        self.assertEqual(state[1]['decision'], 'blocked')
        pr['head']['sha'], http.ancestry = 'e' * 40, 'ahead'
        yield poll(state, emitted, http, [pr])
        self.assertEqual(len(emitted), 2)
        self.assertEqual(emitted[-1]['revision'], 'e' * 40)
        self.assertEqual(emitted[-1]['properties']['tvp_base'], NEXT_BASE)
        self.assertEqual(pr['base']['sha'], OLD_BASE)

    @defer.inlineCallbacks
    def test_blocked_target_advance_is_reported_again_without_build(self):
        for ancestry in ['behind', 'diverged']:
            state, emitted, http = {}, [], HTTP(ancestry=ancestry)
            yield poll(state, emitted, http)
            http.base = NEXT_BASE
            yield poll(state, emitted, http)
            self.assertEqual(emitted, [])
            self.assertEqual(sum(method == 'POST' for method, _, _ in http.calls), 2)

    @defer.inlineCallbacks
    def test_identical_and_full_head_changes_are_admitted(self):
        state, emitted, http, pr = {}, [], HTTP(ancestry='identical'), pull()
        yield poll(state, emitted, http, [pr])
        pr['head']['sha'] = HEAD[:-1] + 'f'
        yield poll(state, emitted, http, [pr])
        self.assertEqual(len(emitted), 2)

    @defer.inlineCallbacks
    def test_ref_resolved_once_per_eligible_branch_per_poll_and_escaped(self):
        state, emitted, http = {}, [], HTTP()
        yield poll(state, emitted, http, [pull(1, 'release/next'), pull(2, 'release/next')], branch='release/next')
        refs = [path for _, path, _ in http.calls if '/git/ref/' in path]
        self.assertEqual(refs, ['/repos/trayanr/tvp/git/ref/heads/release%2Fnext'])
        self.assertEqual(len(emitted), 2)
        self.assertTrue(all('/compare/' not in path or f'{BASE}...{HEAD}' in path for _, path, _ in http.calls))

    @defer.inlineCallbacks
    def test_ineligible_pulls_do_not_cause_network_or_state_writes(self):
        prs = []
        for field, value in [('labels', []), ('draft', True), ('state', 'closed')]:
            pr = pull(); pr[field] = value; prs.append(pr)
        pr = pull(); pr['head']['repo']['full_name'] = 'fork/tvp'; prs.append(pr)
        pr = pull(); pr['head']['sha'] = 'short'; prs.append(pr)
        prs.append(pull(branch='other'))
        state, emitted, http = {}, [], HTTP()
        yield poll(state, emitted, http, prs)
        yield poll(state, emitted, http, [])
        self.assertEqual((state, emitted, http.calls), ({}, [], []))
        yield poll(state, emitted, http)
        self.assertEqual(len(emitted), 1)

    @defer.inlineCallbacks
    def test_http_and_malformed_failures_preserve_state_and_retry(self):
        cases = [
            ('ref', (503, {}), RuntimeError), ('ref', (200, []), ValueError),
            ('ref', (200, {'ref': 'refs/heads/master', 'object': {'sha': BASE.upper(), 'type': 'commit'}}), ValueError),
            ('ref', (200, {'ref': 'refs/heads/master', 'object': {'sha': BASE, 'type': 'tag'}}), ValueError),
            ('ref', (200, {'ref': 'refs/heads/other', 'object': {'sha': BASE, 'type': 'commit'}}), ValueError),
            ('ref', (200, {'ref': 'refs/heads/master', 'object': {'sha': BASE[:-1], 'type': 'commit'}}), ValueError),
            ('compare', (503, {}), RuntimeError), ('compare', (200, {}), ValueError),
            ('compare', (200, {'status': 'unknown'}), ValueError), ('compare', (200, []), ValueError),
            ('compare', (200, {'status': 'ahead'}), ValueError),
            ('compare', (200, {'status': 'ahead', 'base_commit': {'sha': BASE},
                              'merge_base_commit': {'sha': BASE}}), ValueError),
            ('compare', (200, {'status': 'ahead', 'base_commit': {'sha': NEXT_BASE},
                              'merge_base_commit': {'sha': OLD_BASE}}), ValueError),
            ('status', (503, {}), RuntimeError), ('status', (201, {}), ValueError),
        ]
        for kind, failure, error in cases:
            state, emitted, http = {}, [], HTTP()
            yield poll(state, emitted, http)
            saved = deepcopy(state)
            http.base, http.ancestry = NEXT_BASE, 'behind'
            http.failures[kind] = failure
            yield self.assertFailure(poll(state, emitted, http), error)
            self.assertEqual(state, saved)
            self.assertEqual(len(emitted), 1)
            http.failures.clear()
            yield poll(state, emitted, http)
            self.assertEqual(state[1]['decision'], 'blocked')
            self.assertEqual(state[1]['identity'][1], NEXT_BASE)

    @defer.inlineCallbacks
    def test_invalid_json_retries_for_each_endpoint(self):
        for kind in ['ref', 'compare', 'status']:
            state, emitted, http = {}, [], HTTP(ancestry='diverged')
            http.failures[kind] = (201 if kind == 'status' else 200, ValueError('invalid JSON'))
            yield self.assertFailure(poll(state, emitted, http), ValueError)
            self.assertEqual((state, emitted), ({}, []))
            http.failures.clear()
            yield poll(state, emitted, http)
            self.assertEqual(state[1]['decision'], 'blocked')

    @defer.inlineCallbacks
    def test_failed_delivery_is_retried_after_restart(self):
        state, emitted, http = {}, [], HTTP()
        yield self.assertFailure(poll(state, emitted, http, fail=True), RuntimeError)
        self.assertEqual(state, {})
        yield poll(state, emitted, http)
        self.assertEqual(len(emitted), 1)

    @defer.inlineCallbacks
    def test_failed_state_write_retries_instead_of_losing_delivery(self):
        for ancestry in ['ahead', 'behind']:
            state, emitted, http = {}, [], HTTP(ancestry=ancestry)
            failed_source = source(state, emitted, http)
            failed_source._setCurrentRev = lambda *args: defer.fail(RuntimeError('state unavailable'))
            yield self.assertFailure(LabelledPullRequests._processChanges(failed_source, [pull()]), RuntimeError)
            self.assertEqual(state, {})
            yield poll(state, emitted, http)
            # Delivery and recording are not atomic: this boundary is at-least-once.
            self.assertEqual(len(emitted), 2 if ancestry == 'ahead' else 0)
            self.assertEqual(sum(method == 'POST' for method, _, _ in http.calls), 2 if ancestry == 'behind' else 0)
            self.assertIn(state[1]['decision'], ['admitted', 'blocked'])

    @defer.inlineCallbacks
    def test_old_state_does_not_bypass_new_gate(self):
        state, emitted, http = {1: [HEAD, OLD_BASE]}, [], HTTP(ancestry='behind')
        yield poll(state, emitted, http)
        self.assertEqual(emitted, [])
        self.assertEqual(state[1]['decision'], 'blocked')

    @defer.inlineCallbacks
    def test_more_than_one_api_page_is_queued_oldest_first(self):
        calls = []
        def get(path):
            calls.append(path)
            batch = [pull(n) for n in range(101, 1, -1)] if len(calls) == 1 else [pull(1)]
            return response(200, batch)
        pulls = yield LabelledPullRequests._getPulls(SimpleNamespace(owner='trayanr', repo='tvp', _http=SimpleNamespace(get=get)))
        self.assertEqual([pr['number'] for pr in pulls], list(range(1, 102)))
        self.assertEqual(len(calls), 2)
        self.assertIn('page=2', calls[-1])
        state, emitted, http = {}, [], HTTP()
        yield poll(state, emitted, http, pulls)
        self.assertEqual([change['properties']['tvp_pr'] for change in emitted], list(range(1, 102)))
        self.assertEqual(sum('/git/ref/' in path for _, path, _ in http.calls), 1)

    @defer.inlineCallbacks
    def test_bad_pull_list_is_not_an_empty_successful_poll(self):
        for code, body, error in [(503, {}, RuntimeError), (200, {}, ValueError), (200, ValueError('JSON'), ValueError)]:
            result = LabelledPullRequests._getPulls(SimpleNamespace(owner='trayanr', repo='tvp', _http=SimpleNamespace(get=lambda _: response(code, body))))
            yield self.assertFailure(result, error)

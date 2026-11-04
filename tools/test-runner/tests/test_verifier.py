import argparse
import copy
import fcntl
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

import verifier as v


class VerifierTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        path = lambda n: '/nix/store/' + '0' * 32 + '-' + n
        self.plan = {'schema': 1, 'revision': 'a'*40, 'source': path('source'), 'system': 'x86_64-linux',
                     'aggregate': path('all.drv'), 'skipped': [{'name': 'excluded', 'reason': 'reason'}],
                     'jobs': [{'name': 'suite', 'drv': path('suite.drv'), 'outputs': [path('suite')],
                               'tests': [{'name': n, 'drv': path('shared.drv'),
                                          'outputs': [path('shared'), path('secondary')]} for n in ('one', 'two')]},
                              {'name': 'check', 'drv': path('check.drv'), 'outputs': [path('check')], 'tests': []}]}
        self.state = {'phase': 'passed', 'returnCode': 0, 'full': True, 'cancelled': False, 'active': {},
                      'startedAt': 1, 'buildStartedAt': 2, 'updatedAt': 3, 'finishedAt': 4, 'pid': os.getpid(),
                      'reportedFailedDerivations': [], 'testCounts': self.count(3),
                      'jobs': {j['name']: {'status': 'passed', 'cachedAtStart': True, 'completedAt': 3,
                                          'tests': self.count(len(j['tests']) or 1)} for j in self.plan['jobs']}}
        parser = argparse.ArgumentParser()
        v.add_parser(parser.add_subparsers(dest='command'))
        self.args = parser.parse_args(['verify', '--plan', str(self.root/'plan.json'), '--state', str(self.root/'state.json'),
                                      '--output', str(self.root/'report.json')])

    def count(self, n):
        return dict.fromkeys(v.STATUSES[1:], 0) | {'passed': n}

    def save(self):
        for name, value in [('plan', self.plan), ('state', self.state)]:
            (self.root/(name+'.json')).write_text(json.dumps(value))

    def report(self):
        self.save()
        with patch.object(v, 'observe_store', return_value=({'drv': self.plan['aggregate'], 'outputs': []}, 4, 5)):
            return v.verify(self.args)

    def test_occurrences_uniques_checks_multioutputs_unknown_logs(self):
        report = self.report()
        self.assertEqual(report['result'], 'PASS', report)
        self.assertEqual(report['counts'], dict(suites=2, namedOccurrences=2, uniqueNamedDRVs=1,
                                              checks=1, results=3, exclusions=1, verifiedLinks=4))
        self.assertEqual(report['execution']['loggedActivity'], {'status': 'unavailable'})
        self.assertEqual(report['worker']['status'], 'unavailable')

    def test_store_adapter_only_queries_and_normalizes_both_formats(self):
        drv = self.plan['aggregate']
        basename = '0'*32+'-all'
        for output in (basename, '/nix/store/'+basename):
            response = json.dumps({'derivations': {Path(drv).name: {'outputs': {'out': {'path': output}}}}})
            with patch.object(v.subprocess, 'check_output', return_value=response) as query:
                result = v.Store().derivations([drv])
            self.assertEqual(result[drv]['outputs']['out']['path'], '/nix/store/'+basename)
            self.assertEqual(query.call_args.args[0], ['nix', 'derivation', 'show', drv])

    def test_preparation_events_exclude_nix_quote_and_ellipsis(self):
        log = self.root / 'prepare.log'
        paths = ['/nix/store/' + '0' * 32 + '-' + n for n in ('plan.drv', 'tool.drv', 'bare.drv')]
        log.write_text(f"building '{paths[0]}'...\nfetching \"{paths[1]}\"...\nbuilding {paths[2]}\n")
        observed = v.execution(self.state, None, log)['preparation']
        self.assertEqual(observed, {'status': 'observed', 'events': [
            ('building', paths[0]), ('fetching', paths[1]), ('building', paths[2])]})

    def test_raw_run_result_binding_and_read_only_files(self):
        self.save()
        (self.root/'worker.lock').touch()
        self.args.run = self.root
        self.args.plan = self.args.state = None
        aggregate = self.root/'aggregate'; aggregate.mkdir()
        (self.root/'result').symlink_to(aggregate)
        before = {str(p): p.lstat().st_mtime_ns for p in self.root.iterdir()}
        with patch.object(v, 'observe_store', return_value=({'drv': self.plan['aggregate'], 'outputs': [str(aggregate)]}, 4, 5)):
            self.assertEqual(v.verify(self.args)['result'], 'PASS')
            self.assertEqual(before, {str(p): p.lstat().st_mtime_ns for p in self.root.iterdir()})
            (self.root/'result').unlink(); (self.root/'result').symlink_to(self.root/'absent')
            result = v.verify(self.args)
            self.assertEqual(result['result'], 'FAIL')
            self.assertIn('result link', result['failure'])

    def test_duplicate_and_traversal_names_and_types(self):
        for change in [lambda p: p['jobs'].append(copy.deepcopy(p['jobs'][0])),
                       lambda p: p['jobs'][0]['tests'].append(copy.deepcopy(p['jobs'][0]['tests'][0])),
                       lambda p: p['jobs'][0].update(name='../escape'),
                       lambda p: p['jobs'][0]['tests'][0].update(name='/absolute'),
                       lambda p: p['jobs'][0].update(outputs=[]), lambda p: p.update(schema=True),
                       lambda p: p['skipped'][0].update(reason='')]:
            with self.subTest(change=change):
                plan = copy.deepcopy(self.plan); change(plan)
                with self.assertRaises((ValueError, TypeError)):
                    v.validate_plan(plan)
        with self.assertRaisesRegex(ValueError, 'Duplicate JSON'):
            json.loads('{"x":1,"x":2}', object_pairs_hook=v.unique_object)

    def test_terminal_reporting_and_retry_contradictions(self):
        changes = [{'returnCode': False}, {'full': False}, {'cancelled': True}, {'active': {'x': {}}},
                   {'error': 'error'}, {'monitorError': 'error'}, {'reportedFailedDerivations': None},
                   {'testCounts': self.count(2)}, {'attempts': []}, {'finishedAt': 0}, {'pid': True}]
        for change in changes:
            with self.subTest(change=change), self.assertRaises(ValueError):
                v.validate_state(self.plan, self.state | change, 'raw')
        for edit in (lambda s: s['jobs'].pop('check'), lambda s: s['jobs'].update(extra={}),
                     lambda s: s['jobs']['check'].update(tests=self.count(2)),
                     lambda s: s['jobs']['check'].update(cachedAtStart=1),
                     lambda s: s['jobs']['check'].update(attempt='/retry')):
            state = copy.deepcopy(self.state); edit(state)
            with self.assertRaises(ValueError):
                v.validate_state(self.plan, state, 'raw')

    def test_export_adapter_does_not_guess_missing_fields(self):
        with self.assertRaises(ValueError):
            v.validate_state(self.plan, self.state, 'ci-status')
        state = self.state | dict(source=self.plan['source'], declaredBroken=self.plan['skipped'],
                                  counts={'passed': 2}, run='/exported/run')
        v.validate_state(self.plan, state | {'updatedAt': 5}, 'ci-status')
        with self.assertRaisesRegex(ValueError, 'terminal times'):
            v.validate_state(self.plan, self.state | {'updatedAt': 5}, 'raw')
        with self.assertRaises(ValueError):
            v.validate_state(self.plan, state | {'counts': {'passed': 3}}, 'ci-status')

    def test_whole_reference_comparison_and_revision_only(self):
        ref = self.root/'reference.json'; ref.write_text(json.dumps(self.plan))
        self.args.reference_plan = ref
        self.plan['revision'] = 'b'*40
        self.assertEqual(self.report()['result'], 'FAIL')
        self.args.revision_only = True
        self.assertEqual(self.report()['result'], 'PASS')
        for edit in (lambda p: p.update(source=p['source']+'changed'),
                     lambda p: p['jobs'][0]['tests'][0]['outputs'].append(p['source']+'output'),
                     lambda p: p['skipped'][0].update(reason='changed')):
            plan = copy.deepcopy(self.plan); edit(self.plan)
            self.assertEqual(self.report()['result'], 'FAIL')
            self.plan = plan

    def test_graph_informational_and_explicit_invariants(self):
        self.args.graph_before, self.args.graph_after = self.root/'before', self.root/'after'
        for p, entries in [(self.args.graph_before, {'old': {'drv': 'a', 'out': 'b'}}),
                           (self.args.graph_after, {'new': {'drv': 'c', 'out': 'd'}})]:
            p.write_text(json.dumps({'schema': 1, 'entries': entries}))
        report = self.report()
        self.assertEqual(report['result'], 'PASS')
        self.assertEqual(report['graphDelta']['removed'], ['old'])
        self.args.invariants = self.root/'invariants'
        self.args.invariants.write_text(json.dumps({'schema': 1, 'graphEntries': {'old': {'drv': 'a', 'out': 'b'}}}))
        self.assertEqual(self.report()['result'], 'FAIL')

    def test_unsupported_optional_shapes_fail_with_reports(self):
        self.args.invariants = self.root/'invariants'
        for value in ([], {'schema': True}, {'schema': 1, 'planJobs': []},
                      {'schema': 1, 'planJobs': {'typo': None}},
                      {'schema': 1, 'graphEntries': {'typo': None}},
                      {'schema': 1, 'graphDelta': None}, {'schema': 1, 'graphDelta': {}}):
            self.args.invariants.write_text(json.dumps(value))
            self.assertEqual(self.report()['result'], 'FAIL')
        self.args.invariants = None
        self.args.graph_before, self.args.graph_after = self.root/'g1', self.root/'g2'
        self.args.graph_before.write_text('[]'); self.args.graph_after.write_text('[]')
        self.assertEqual(self.report()['result'], 'FAIL')

    def test_live_worker_lock_is_read_only_and_reused_pid_is_ok(self):
        lock = self.root/'worker.lock'; lock.touch()
        before = set(self.root.iterdir())
        with lock.open('rb') as stream:
            fcntl.flock(stream, fcntl.LOCK_EX)
            with self.assertRaisesRegex(ValueError, 'lock still held'):
                v.worker_observation(self.root, self.state)
        self.assertFalse(v.worker_observation(self.root, self.state)['boundWorkerLive'])
        with patch.object(Path, 'read_bytes', return_value=b'python\0_work\0'+os.fsencode(str(self.root))+b'\0'):
            with self.assertRaisesRegex(ValueError, 'still live'):
                v.worker_observation(self.root, self.state)
        self.assertEqual(before, set(self.root.iterdir()))

    def test_immutable_output_and_changed_input_fail(self):
        report = self.report()
        v.atomic_report(self.args.output, report, report['inputs'])
        v.atomic_report(self.args.output, report, report['inputs'])
        with self.assertRaisesRegex(ValueError, 'Conflicting'):
            v.atomic_report(self.args.output, report | {'result': 'FAIL'}, report['inputs'])
        with self.assertRaisesRegex(ValueError, 'aliases'):
            v.atomic_report(self.args.plan, report, report['inputs'])
        def change(*_):
            self.args.plan.write_text('{}')
            return ({}, 4, 5)
        self.save()
        with patch.object(v, 'observe_store', side_effect=change):
            result = v.verify(self.args)
        self.assertEqual(result['result'], 'FAIL')
        self.assertIn('hash changed', result['failure'])
        with self.assertRaisesRegex(ValueError, "Input hash changed"):
            v.atomic_report(self.root/"new-report", report, report["inputs"])

    def test_actual_links_all_outputs_and_derivation_bindings(self):
        # A fake store adapter supplies metadata, but all link observations are real.
        plan = copy.deepcopy(self.plan)
        for item in [i for j in plan['jobs'] for i in [j]+j['tests']]:
            item['outputs'] = [str(self.root/Path(p).name) for p in item['outputs']]
        plan['source'] = str(self.root/'source'); Path(plan['source']).mkdir()
        aggregate = self.root/'aggregate'; aggregate.mkdir()
        drvs = {}
        for job in plan['jobs']:
            for item in [job]+job['tests']:
                for output in item['outputs']:
                    Path(output).mkdir(exist_ok=True)
                drvs[item['drv']] = {'system': plan['system'], 'outputs': {str(i): {'path': p} for i,p in enumerate(item['outputs'])}}
            (aggregate/job['name']).symlink_to(job['outputs'][0])
            for test in job['tests']:
                (Path(job['outputs'][0])/test['name']).symlink_to(test['outputs'][0])
        drvs[plan['aggregate']] = {'system': plan['system'], 'outputs': {'out': {'path': str(aggregate)}}}
        class FakeStore:
            def derivations(self, paths):
                return {p: drvs[p] for p in paths}
            def valid(self, paths):
                return {p for p in paths if Path(p).exists()}
        fake = FakeStore()
        with patch.object(v, 'store_path'):
            self.assertEqual(v.observe_store(plan, None, fake)[1], 4)
            with self.assertRaisesRegex(ValueError, 'unrelated'):
                v.observe_store(plan, Path('/wrong'), fake)
            secondary = Path(plan['jobs'][0]['tests'][0]['outputs'][1]); secondary.rmdir()
            with self.assertRaisesRegex(ValueError, 'Missing/invalid'):
                v.observe_store(plan, None, fake)
            secondary.mkdir()
            for kind in ('wrong', 'broken', 'regular', 'extra', 'missing'):
                link = aggregate/'suite'; link.unlink()
                if kind in ('wrong', 'broken'):
                    link.symlink_to(plan['source'] if kind == 'wrong' else self.root/'absent')
                elif kind == 'regular':
                    link.mkdir()
                elif kind == 'extra':
                    link.symlink_to(plan['jobs'][0]['outputs'][0]); (aggregate/'extra').touch()
                with self.assertRaises(ValueError):
                    v.observe_store(plan, None, fake)
                if kind == 'regular': link.rmdir()
                elif link.is_symlink(): link.unlink()
                if kind == 'extra': (aggregate/'extra').unlink()
                link.symlink_to(plan['jobs'][0]['outputs'][0])
            drvs[plan['jobs'][0]['drv']]['outputs']['extra'] = {'path': '/unexpected'}
            with self.assertRaisesRegex(ValueError, 'outputs differ'):
                v.observe_store(plan, None, fake)


if __name__ == '__main__':
    unittest.main()

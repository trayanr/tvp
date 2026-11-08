import argparse
import copy
import json
import unittest
from unittest.mock import patch

import representative as r
import verifier as v
import test_verifier as fixtures


class RepresentativeTests(unittest.TestCase):
    def setUp(self):
        fixture = fixtures.VerifierTests()
        fixture.setUp()
        self.addCleanup(fixture.doCleanups)
        self.root = fixture.root
        suite, check = fixture.plan['jobs']
        ownership = check | {'name': 'check-package-runtime-ownership-latest'}
        policy = check | {'name': 'check-runtime-policy-latest', 'drv': check['drv'].replace('check', 'policy'),
                          'outputs': [check['outputs'][0].replace('check', 'policy')]}
        old = copy.deepcopy(suite) | {'name': 'suite-old'}
        self.reference = fixture.plan | {'jobs': [suite, old, ownership, policy]}
        self.plan = self.reference | {'jobs': [suite, ownership, policy]}
        alias = {'family': 'widget', 'version': '1.10', 'job': 'suite', 'jobDRV': suite['drv'],
                 'packageDRV': suite['drv'].replace('suite', 'package'),
                 'out': suite['outputs'][0].replace('suite', 'package'),
                 'outputs': [suite['outputs'][0].replace('suite', 'package')]}
        subject = {k: self.plan[k] for k in ('revision', 'source', 'system')}
        self.catalogue = {'schema': 'tvp.representative-catalogue/v1', 'subject': subject,
                          'families': {'widget': {'alias': alias,
                              'versions': [alias, alias | {'version': '1.9', 'job': 'suite-old'}]}}, 'profiles': {}}
        checks = [{'job': j['name'], 'reason': 'strict scoped ownership'} for j in [ownership, policy]]
        self.selection = {'schema': 'tvp.representative-selection/v1', 'subject': subject,
                          'validationScope': r.SCOPE, 'families': {'widget': alias},
                          'profiles': [], 'compatibility': [], 'checks': checks,
                          'selectedJobs': sorted(j['name'] for j in self.plan['jobs']),
                          'omittedJobs': ['suite-old'], 'omittedOrdinaryVersions': 1}
        self.selection = copy.deepcopy(self.selection)
        self.plan = copy.deepcopy(self.plan)
        self.state = fixture.state | {'full': False, 'testCounts': fixture.count(4),
            'jobs': {j['name']: {'status': 'passed', 'cachedAtStart': True, 'completedAt': 3,
                               'tests': fixture.count(len(j['tests']) or 1)} for j in self.plan['jobs']}}
        parser = argparse.ArgumentParser()
        r.add_parser(parser.add_subparsers(dest='command'))
        argv = ['verify-representative']
        for key, value in [('run', self.root), ('reference-plan', self.root/'reference.json'),
                           ('catalogue', self.root/'catalogue.json'), ('selection-manifest', self.root/'selection.json'),
                           ('output', self.root/'report.json')]:
            argv += ['--'+key, str(value)]
        for key in subject:
            argv += ['--expect-'+key, subject[key]]
        self.args = parser.parse_args(argv)
        for name in ['nix.log', 'prepare.log', 'worker.lock']:
            (self.root/name).touch()

    def report(self):
        for name, value in [('reference', self.reference), ('catalogue', self.catalogue),
                            ('plan', self.plan), ('state', self.state)]:
            (self.root/(name+'.json')).write_text(json.dumps(value))
        selection = self.selection | {'referencePlanSHA256': v.digest(self.args.reference_plan),
                                     'catalogueSHA256': v.digest(self.args.catalogue)}
        (self.root/'selection.json').write_text(json.dumps(selection))
        with patch.object(r, 'observe_selected', return_value={'actualLocalStoreObservation': True}):
            return r.verify(self.args)

    def test_partial_certificate_and_full_verifier_are_distinct(self):
        report = self.report()
        self.assertEqual(report['result'], 'PASS')
        self.assertFalse(report['full'])
        self.assertEqual(report['reference']['omittedOrdinaryVersions'], 1)
        with self.assertRaisesRegex(ValueError, 'full=True'):
            v.validate_state(self.plan, self.state, 'raw')

    def test_missing_extra_historical_and_output_projection_rejected(self):
        for change in [lambda: self.plan['jobs'].append(self.reference['jobs'][1]),
                       lambda: self.plan['jobs'].pop(),
                       lambda: self.plan['jobs'][0]['tests'][0].update(outputs=['/nix/store/'+'0'*32+'-wrong']),
                       lambda: self.plan.update(source='/nix/store/'+'0'*32+'-wrong')]:
            before = copy.deepcopy(self.plan)
            change()
            self.assertEqual(self.report()['result'], 'FAIL')
            self.plan = before

    def test_wrong_alias_omissions_checks_and_subject_rejected(self):
        for change in [lambda: self.selection['families']['widget'].update(version='1.9'),
                       lambda: self.selection.update(omittedJobs=[]),
                       lambda: self.selection.update(omittedOrdinaryVersions=0),
                       lambda: self.selection['checks'].pop(),
                       lambda: self.selection['checks'][0].update(job='check-package-runtime-ownership'),
                       lambda: self.selection['checks'][0].update(reason='')]:
            selection, catalogue = copy.deepcopy(self.selection), copy.deepcopy(self.catalogue)
            change()
            self.assertEqual(self.report()['result'], 'FAIL')
            self.selection, self.catalogue = selection, catalogue
        self.args.expect_revision = 'b'*40
        self.assertEqual(self.report()['result'], 'FAIL')

    def test_terminal_scope_retry_and_missing_results_rejected(self):
        for change in [{'full': True}, {'cancelled': True}, {'retryOf': '/old'},
                       {'reportedFailedDerivations': ['/failed']}, {'returnCode': 1}, {'phase': 'cancelled'}]:
            previous = copy.deepcopy(self.state)
            self.state.update(change)
            self.assertEqual(self.report()['result'], 'FAIL')
            self.state = previous

    def test_store_bindings_secondary_outputs_ownership_and_no_aggregate(self):
        plan, catalogue = copy.deepcopy(self.plan), copy.deepcopy(self.catalogue)
        for job in plan['jobs']:
            for item in [job] + job['tests']:
                item['outputs'] = [str(self.root/p.rsplit('/', 1)[1]) for p in item['outputs']]
        alias = catalogue['families']['widget']['alias']
        alias['outputs'] = [str(self.root/'package')]
        alias['out'] = alias['outputs'][0]
        catalogue['families']['widget']['versions'][0] = alias
        roots = {'suite': alias['out']}
        metadata = {}
        for job in plan['jobs']:
            for item in [job] + job['tests']:
                metadata[item['drv']] = {'system': plan['system'],
                    'outputs': {str(i): {'path': p} for i, p in enumerate(item['outputs'])}}
                for output in item['outputs']:
                    path = self.root/output.rsplit('/', 1)[1]
                    if not path.exists(): path.touch()
        metadata[alias['packageDRV']] = {'system': plan['system'], 'outputs': {'out': {'path': alias['out']}}}
        attrs = {'runtimeRoots': roots, 'registeredPaths': []}
        metadata[plan['jobs'][1]['drv']]['env'] = {'__json': json.dumps(attrs)}
        plan['source'] = str(self.root/'source')
        (self.root/'source/audits').mkdir(parents=True)
        (self.root/'source/audits/runtime-baseline.json').write_text('{}')
        suite = self.root/plan['jobs'][0]['outputs'][0].rsplit('/', 1)[1]
        suite.unlink(); suite.mkdir()
        for test in plan['jobs'][0]['tests']:
            (suite/test['name']).symlink_to(test['outputs'][0])
        ownership = {'clean': ['suite'], 'legacy': {}, 'unexpected': {}, 'stale': {}}
        ownership_file = self.root/plan['jobs'][1]['outputs'][0].rsplit('/', 1)[1]
        ownership_file.write_text(json.dumps(ownership))
        policy_file = self.root/plan['jobs'][2]['outputs'][0].rsplit('/', 1)[1]
        policy_file.write_text(json.dumps({'roots': ['suite'], 'legacy': {}, 'registeredPaths': []}))
        class Store:
            def derivations(inner, paths):
                self.assertNotIn(plan['aggregate'], paths)
                return metadata
            def valid(inner, paths): return set(paths)
        coverage = r.observe_selected(plan, catalogue, self.selection, Store())
        self.assertFalse(coverage['fullAggregateObservedOrRequired'])
        metadata[plan['jobs'][1]['drv']]['structuredAttrs'] = attrs
        del metadata[plan['jobs'][1]['drv']]['env']['__json']
        self.assertEqual(r.observe_selected(plan, catalogue, self.selection, Store()), coverage)
        del metadata[plan['jobs'][1]['drv']]['structuredAttrs']
        metadata[plan['jobs'][1]['drv']]['env']['__json'] = json.dumps(attrs)
        for field in ['unexpected', 'stale']:
            ownership_file.write_text(json.dumps(ownership | {field: {'suite': ['/foreign']}}))
            with self.assertRaisesRegex(ValueError, 'ownership audit failed'):
                r.observe_selected(plan, catalogue, self.selection, Store())
        ownership_file.write_text(json.dumps(ownership))
        metadata[plan['jobs'][1]['drv']]['env']['__json'] = json.dumps({'runtimeRoots': roots | {'old': '/old'}})
        with self.assertRaisesRegex(ValueError, 'derivation roots differ'):
            r.observe_selected(plan, catalogue, self.selection, Store())
        metadata[plan['jobs'][1]['drv']]['env']['__json'] = json.dumps(attrs)
        shared = plan['jobs'][0]['tests'][0]['drv']
        metadata[shared]['outputs'].pop('1')
        with self.assertRaisesRegex(ValueError, 'binding differs'):
            r.observe_selected(plan, catalogue, self.selection, Store())

    def test_unknown_structured_metadata_rejected(self):
        for metadata in [{'env': {}}, {'structuredAttrs': []}, {'env': {'__json': '[]'}}]:
            with self.assertRaises((ValueError, KeyError)):
                r.structured_attributes(metadata)


if __name__ == '__main__':
    unittest.main()

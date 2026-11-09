import copy
import hashlib
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

import batch_report as b


class BatchReportTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.source = dict(path='/nix/store/' + '0'*32 + '-source', revision='a'*40,
                           tree='b'*40, narHash='sha256-' + 'A'*43 + '=')
        self.old = self.source | dict(revision='c'*40, tree='d'*40, path='/nix/store/' + '1'*32 + '-source')
        self.scope = dict(families=['zip', 'unzip'], description='Controlled receipt fixtures, not runtime proof')
        self.manifest = dict(schema='tvp.batch-manifest/v1', subject=self.source, scope=self.scope, references=[])
        self.docs = {}
        self.focused()

    def save(self, name, value):
        path = self.root / name
        path.write_text(json.dumps(value))
        return dict(path=name, sha256=hashlib.sha256(path.read_bytes()).hexdigest(), format='json')

    def add(self, identifier, kind, claims, subject=None, lineage=None, artifacts=None):
        doc = dict(schema='tvp.batch-evidence/v1', kind=kind, subject=subject or self.source, scope=self.scope,
                   claims=claims, artifacts=artifacts or [])
        self.docs[identifier] = doc
        artifact = self.save(identifier + '.json', doc)
        ref = {k: doc[k] for k in ('kind', 'subject', 'scope')}
        self.manifest['references'].append(dict(id=identifier, path=artifact['path'], sha256=artifact['sha256'],
                                               lineage=lineage or [], **ref))
        return doc

    def focused(self, identifier='focused', subject=None, lineage=None):
        return self.add(identifier, 'focused', dict(status='PASS', records=[dict(id='unit', status='PASS', detail='fixture')],
                                                   limitations=['Self-declared fixture']), subject, lineage)

    def review(self, subject=None, lineage=None):
        return self.add('review', 'review', dict(status='COMPLETE', findings=[dict(id='R1', detail='repair needed')],
                                                limitations=[]), subject, lineage)

    def latest(self, status='PASS', terminal=True, active=False):
        s = self.source
        observation = dict(schema='tvp.latest-verification/v1', full=False, machineReady=False, mergeEligible=False,
                            result=status, coverage=dict(allDeclaredSiblings=True, availabilityOnly=True,
                                                        freshExecutionCertified=False, validSelectedOutputs=3, links=2), subject=dict(
                               source=s['path'], revision=s['revision'], tree=s['tree'], snapshot=dict(
                                   path=s['path'], revision=s['revision'], locked=dict(rev=s['revision'], narHash=s['narHash']))))
        self.add('latest', 'latest', dict(status=status, terminal=terminal, workerActive=active,
                                         observation=self.save('observation.json', observation), limitations=[]))

    def run_report(self):
        self.save('manifest.json', self.manifest)
        return b.collect(self.root / 'manifest.json')

    def refresh(self, identifier):
        row = self.save(identifier + '.json', self.docs[identifier])
        next(r for r in self.manifest['references'] if r['id'] == identifier)['sha256'] = row['sha256']

    def test_no_subprocess_network_store_or_publication_actions(self):
        self.latest()
        with patch.object(subprocess, 'Popen', side_effect=AssertionError('subprocess forbidden')), \
             patch.object(os, 'system', side_effect=AssertionError('shell forbidden')), \
             patch.object(socket, 'socket', side_effect=AssertionError('network forbidden')):
            report = self.run_report()
            b.publish(report, self.root/'report.json', self.root/'summary.txt')
        self.assertEqual(report['state'], 'INCOMPLETE')
        for flag in ('full', 'freshExecutionCertified', 'machineReady', 'mergeEligible'):
            self.assertIs(report[flag], False)
        self.assertIn('HARDENING-GATE-1', report['openGates'])

    def test_complete_collection_is_not_approval(self):
        self.add('review', 'review', dict(status='COMPLETE', findings=[], limitations=[]))
        self.add('qualification', 'qualification', dict(records=[], openGates=[], limitations=[]))
        self.latest()
        report = self.run_report()
        self.assertEqual(report['state'], 'COLLECTED')
        self.assertFalse(report['machineReady'])
        self.assertTrue(report['openGates'])

    def test_source_and_envelope_mismatch(self):
        ref = self.manifest['references'][0]
        for key, value in self.old.items():
            if value == self.source[key]:
                continue
            with self.subTest(key=key):
                original = ref['subject']
                ref['subject'] = self.source | {key: value}
                with self.assertRaisesRegex(ValueError, 'binding mismatch'):
                    self.run_report()
                ref['subject'] = original
        self.docs['focused']['subject'] = self.old
        ref['subject'] = self.old
        self.refresh('focused')
        with self.assertRaisesRegex(ValueError, 'Source mismatch'):
            self.run_report()

    def test_hash_mismatch_and_exact_parsed_bytes(self):
        (self.root/'focused.json').write_text('{}')
        with self.assertRaisesRegex(ValueError, 'hash mismatch'):
            self.run_report()
        self.refresh('focused')
        self.assertEqual(self.run_report()['observed']['inputs'][str(self.root/'focused.json')],
                         hashlib.sha256((self.root/'focused.json').read_bytes()).hexdigest())

    def test_unresolved_and_explicit_repair(self):
        self.review()
        self.assertEqual(self.run_report()['state'], 'UNRESOLVED')
        self.docs['review']['subject'] = self.old
        ref = self.manifest['references'][-1]
        ref.update(subject=self.old, lineage=['repair'])
        self.refresh('review')
        self.add('resolution', 'resolution', dict(review='review', finding='R1', status='RESOLVED', detail='fixed', proofs=['focused']))
        self.add('repair', 'lineage', dict(mode='repair', **{'from': self.old}, to=self.source, reason='Explicit repair',
                                         proofs=['focused'], resolutions=['resolution']))
        report = self.run_report()
        self.assertEqual(report['findings'][0]['resolution']['status'], 'RESOLVED')
        self.assertEqual(report['state'], 'INCOMPLETE')
        self.docs['repair']['claims']['resolutions'] = []
        self.refresh('repair')
        with self.assertRaisesRegex(ValueError, 'Repair requires'):
            self.run_report()

    def test_required_hashes_reject_null(self):
        manifest, docs = copy.deepcopy(self.manifest), copy.deepcopy(self.docs)
        for kind in ('reference', 'artifact', 'observation', 'protection'):
            with self.subTest(kind=kind):
                self.manifest, self.docs = copy.deepcopy(manifest), copy.deepcopy(docs)
                if kind == 'reference':
                    self.manifest['references'][0]['sha256'] = None
                elif kind == 'artifact':
                    artifact = self.save('payload.json', {'fixture': True})
                    artifact['sha256'] = None
                    self.docs['focused']['artifacts'] = [artifact]
                    self.refresh('focused')
                elif kind == 'observation':
                    self.latest()
                    self.docs['latest']['claims']['observation']['sha256'] = None
                    self.refresh('latest')
                else:
                    path = self.root / 'protected'; path.write_text('unchanged')
                    self.add('protection', 'protection', dict(domain='fixture', files=[dict(path=str(path), sha256=None)]))
                with self.assertRaisesRegex(ValueError, 'Invalid SHA256'):
                    self.run_report()

    def test_latest_pass_requires_consistent_complete_coverage(self):
        self.latest()
        valid = json.loads((self.root/'observation.json').read_text())
        coverage = valid['coverage']
        mutations = [None, [], {}, {k: v for k, v in coverage.items() if k != 'links'}]
        for key, value in [('allDeclaredSiblings', False), ('allDeclaredSiblings', 1),
                           ('availabilityOnly', False), ('freshExecutionCertified', True),
                           ('validSelectedOutputs', 0), ('validSelectedOutputs', True),
                           ('validSelectedOutputs', -1), ('validSelectedOutputs', 1.5),
                           ('links', -1), ('links', False), ('links', '2')]:
            mutations.append(coverage | {key: value})
        for index, value in enumerate(['missing', *mutations]):
            with self.subTest(index=index):
                observation = copy.deepcopy(valid)
                if value == 'missing':
                    observation.pop('coverage')
                else:
                    observation['coverage'] = value
                self.docs['latest']['claims']['observation'] = self.save('observation.json', observation)
                self.refresh('latest')
                with self.assertRaisesRegex(ValueError, 'coverage'):
                    self.run_report()
        self.docs['latest']['claims']['observation'] = self.save('observation.json', valid)
        self.refresh('latest')
        self.assertEqual(self.run_report()['latestObservations'][0]['observation']['coverage'], coverage)

    def test_two_step_proof_reuse_and_broken_chain(self):
        middle = self.source | dict(revision='e'*40)
        self.focused('old-proof', self.old, ['reuse-one', 'reuse-two'])
        self.focused('middle-proof', middle, ['reuse-two'])
        self.add('reuse-one', 'lineage', dict(mode='proof-reuse', **{'from': self.old}, to=middle, reason='Scoped identity comparison',
                                            proofs=['middle-proof'], resolutions=[]), middle, ['reuse-two'])
        self.add('reuse-two', 'lineage', dict(mode='proof-reuse', **{'from': middle}, to=self.source, reason='Scoped identity comparison',
                                            proofs=['focused'], resolutions=[]))
        self.assertEqual(self.run_report()['state'], 'INCOMPLETE')
        self.docs['reuse-two']['claims']['from'] = self.old
        self.refresh('reuse-two')
        with self.assertRaisesRegex(ValueError, 'Broken lineage'):
            self.run_report()

    def test_resolution_unknown_duplicate_and_failed_proof(self):
        self.review()
        c = dict(review='review', finding='R1', status='RESOLVED', detail='fixture repair', proofs=['focused'])
        self.add('resolution', 'resolution', c)
        self.docs['focused']['claims']['status'] = 'FAIL'; self.refresh('focused')
        with self.assertRaisesRegex(ValueError, 'passing focused'):
            self.run_report()
        self.docs['focused']['claims']['status'] = 'PASS'; self.refresh('focused')
        c['finding'] = 'unknown'; self.refresh('resolution')
        with self.assertRaisesRegex(ValueError, 'Unknown finding'):
            self.run_report()
        c['finding'] = 'R1'; self.refresh('resolution')
        self.add('duplicate', 'resolution', c)
        with self.assertRaisesRegex(ValueError, 'duplicate resolution'):
            self.run_report()

    def test_latest_failed_active_partial_not_promoted(self):
        for status, terminal, active in [('FAIL', True, False), ('ACTIVE', False, True), ('PARTIAL', True, False), ('PASS', False, True)]:
            with self.subTest(status=status, terminal=terminal):
                self.manifest['references'] = self.manifest['references'][:1]
                self.latest(status, terminal, active)
                report = self.run_report()
                self.assertEqual(report['state'], 'UNRESOLVED')
                self.assertEqual(report['latestObservations'][0]['observation']['result'], status)

    def test_latest_source_mismatch(self):
        self.latest()
        observation = json.loads((self.root/'observation.json').read_text())
        observation['subject']['tree'] = 'f'*40
        self.docs['latest']['claims']['observation'] = self.save('observation.json', observation)
        self.refresh('latest')
        with self.assertRaisesRegex(ValueError, 'source mismatch'):
            self.run_report()

    def test_nonpass_records_and_open_gate_survive(self):
        rows = [dict(id=s, status=s, detail='raw retained ' + s) for s in b.STATUSES]
        self.add('qualification', 'qualification', dict(records=rows, openGates=['HARDENING-GATE-1'], limitations=['No waiver']))
        report = self.run_report()
        self.assertEqual(report['state'], 'UNRESOLVED')
        self.assertEqual(report['claims']['qualification']['claims']['records'], rows)
        for row in rows:
            self.assertIn(row['detail'], b.summary(report))

    def test_separate_protection_domains_and_relative_artifacts(self):
        for domain, contents in [('old-dirty', 'old'), ('clean-source', 'clean')]:
            path = self.root / domain; path.write_text(contents)
            self.add(domain, 'protection', dict(domain=domain, files=[dict(path=str(path), sha256=b.hashlib.sha256(path.read_bytes()).hexdigest())]))
        report = self.run_report()
        self.assertEqual(report['claims']['old-dirty']['claims']['domain'], 'old-dirty')
        self.assertNotEqual(report['claims']['old-dirty']['claims']['files'][0]['sha256'], report['claims']['clean-source']['claims']['files'][0]['sha256'])
        (self.root/'clean-source').write_text('changed')
        with self.assertRaisesRegex(ValueError, 'hash mismatch'):
            self.run_report()

    def test_repeat_and_conflict_json_summary_input_alias(self):
        report = self.run_report()
        output, summary = self.root/'report.json', self.root/'summary.txt'
        b.publish(report, output, summary)
        before = (output.stat().st_mtime_ns, summary.read_bytes())
        b.publish(report, output, summary)
        self.assertEqual(before, (output.stat().st_mtime_ns, summary.read_bytes()))
        self.assertIn(b.hashlib.sha256(output.read_bytes()).hexdigest(), summary.read_text())
        changed = copy.deepcopy(report); changed['state'] = 'UNRESOLVED'
        with self.assertRaisesRegex(ValueError, 'Conflicting'):
            b.publish(changed, output, summary)
        with self.assertRaisesRegex(ValueError, 'aliases'):
            b.publish(report, self.root/'manifest.json')
        with self.assertRaisesRegex(ValueError, 'alias'):
            b.publish(report, output, output)
        summary.write_text('conflict')
        with self.assertRaisesRegex(ValueError, 'Conflicting'):
            b.publish(report, self.root/'new.json', summary)
        self.assertFalse((self.root/'new.json').exists())

    def test_changed_input_before_publication(self):
        report = self.run_report()
        (self.root/'focused.json').write_text('{}')
        with self.assertRaisesRegex(ValueError, 'Input hash changed'):
            b.publish(report, self.root/'report.json')
        self.assertFalse((self.root/'report.json').exists())

    def test_malformed_duplicate_nonfinite_unknown_fields_and_bad_refs(self):
        for raw in ['{', '{"schema":1,"schema":2}', '{"a":NaN}', '{"a":1e999}', '[]']:
            (self.root/'bad.json').write_text(raw)
            with self.assertRaises(ValueError):
                b.collect(self.root/'bad.json')
        for mutation in [lambda m: m.update(machineReady=True), lambda m: m['references'].append(m['references'][0]),
                         lambda m: m['references'][0].update(sha256='invalid'),
                         lambda m: m['references'][0].update(path='missing.json'),
                         lambda m: m['references'][0].update(lineage=['missing']),
                         lambda m: m['references'][0].update(scope=dict(families=['other'], description='wrong'))]:
            old = copy.deepcopy(self.manifest)
            mutation(self.manifest)
            with self.assertRaises((ValueError, OSError)):
                self.run_report()
            self.manifest = old
        (self.root/'focused.json').write_text('{"kind":"focused","kind":"review"}')
        self.manifest['references'][0]['sha256'] = hashlib.sha256((self.root/'focused.json').read_bytes()).hexdigest()
        with self.assertRaisesRegex(ValueError, 'Duplicate JSON key'):
            self.run_report()

    def test_cli(self):
        self.save('manifest.json', self.manifest)
        runner = Path(b.__file__).with_name('runner.py')
        result = subprocess.run([sys.executable, str(runner), 'report', '--manifest', str(self.root/'manifest.json'),
                                 '--output', str(self.root/'report.json'), '--summary', str(self.root/'summary.txt')], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)['state'], 'INCOMPLETE')


if __name__ == '__main__':
    unittest.main()

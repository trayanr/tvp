import copy
import json
import unittest
from unittest.mock import patch
import migration as m


def row(name, family='x', constructor='owned', failure=None, namespace='canonical', base='source-gnu-candidate', status='ok'):
    return dict(id=f'{namespace}/{name}', namespace=namespace, name=name, family=family,
                version=name.rsplit('_', 1)[-1], constructor=constructor, failure=failure,
                compliant=failure is None, selectedBase=base, status=status)


def facts():
    rows = [row('x_1', constructor='legacy', failure='legacy-no-plan', base=None),
            row('x_2', failure='owned-unsplit'), row('x_3'),
            row('y_1', 'y', namespace='variants.old', constructor='native-plan',
                failure='native-plan-constructor', base='retained'),
            row('z_1', 'z', constructor='unavailable', failure='evaluation-failed', status='broken')]
    return dict(schema='tvp.migration-facts/v1', system='test-system', scope='ordinary policy',
                source=dict(path='/source', revision='rev'), rows=rows,
                latest=dict(families={'x':dict(job='x_3', version='3')},
                            skipped=[dict(family='z', reason='all broken')]),
                splitPolicy=dict(status='PASS_WITH_EXISTING_DEBT', success=True, allSplit=False, errors=[]),
                outsideOrdinaryScope=dict(disposition='Separate audit required', producers={
                    'bootstrap.seed':dict(role='bootstrap', disposition='requires audit', validation='OUTSIDE')}))


def progress():
    return dict(schema=1, status='running', updatedAt='2026-01-01',
                workingBaseline=dict(normalized='/source', head='rev'),
                pausedByUser=dict(status='PAUSED_BY_USER', noNewWorkUntilUserResumes=True, R2='ABI pending'),
                currentWave='next', currentStep='review', olderRecipeMigration=dict(
                    ordinaryReleasesPortedThisPass=12, representativesBuiltThisPass=5,
                    evaluationOnlyThisPass=4, additionalArtifactBuildsWithoutNamedQualificationThisPass=3),
                waves={'next':dict(sourceAccepted=False, selectedReleases=4, implementedReleases=4,
                                   representativesBuilt=1, preflightEvaluationOnly=['a','b','c'],
                                   sourceReviewPending=True, source={'PR':'https://example.test/1'},
                                   secret='must not leak')},
                pendingDownstreamQualification={'runtimes':dict(status='PENDING_UNWAIVED',count=2)},
                ci={'status':'OFF'}, defaultSwitchHardeningGate=dict(status='OPEN',defaultSwitchBlocked=True))


class RepositoryTests(unittest.TestCase):
    def test_classifications_and_scope(self):
        r = m.report(facts())
        s = r['repository']['summary']
        self.assertEqual(s, {
            'total':5,'canonical':4,'publicVariants':1,'declaredBroken':1,
            'constructors':{'owned':2,'legacy':1,'native-plan':1,'unavailable':1},
            'sourceCandidateSelected':3,'splitCompliant':1,'splitDebt':4,
            'remainingLegacyPorts':1,'ownedUnsplit':1,'otherSplitDebt':2})
        self.assertEqual(r['repository']['strictSplitAdmission'], 'blocked')
        self.assertEqual(r['repository']['latest']['selected'][0]['job'], 'x_3')
        self.assertEqual(r['repository']['outsideOrdinaryScope']['producers'].keys(), {'bootstrap.seed'})
        self.assertIsNone(r['workflow'])

    def test_family_json_and_text_agreement(self):
        r = json.loads(json.dumps(m.report(facts(), 'x')))
        self.assertEqual(r['repository']['summary']['total'],3)
        text=m.render(r)
        self.assertIn('3 rows = 3 canonical + 0 public variants', text)
        self.assertIn('Split compliant: 1/3; debt 2', text)
        self.assertIn('canonical/x_1 1: legacy',text)
        self.assertIn('qualification, pause, holds and CI are unknown',text)
        self.assertEqual(set(r['repository']['families']), {'x'})
        with self.assertRaisesRegex(m.Invalid, 'unknown family'):
            m.report(facts(), 'missing')

    def test_zero_denominator(self):
        f=facts();f['rows']=[];f['latest']={'families':{},'skipped':[]}
        f['splitPolicy']['allSplit']=True
        r=m.report(f)
        self.assertEqual(r['repository']['summary']['total'],0)
        self.assertIn('0/0',m.render(r))
        self.assertNotIn('%',m.render(r))

    def test_all_split_is_not_admission(self):
        f=facts();f['rows']=[f['rows'][2]];f['latest']['skipped']=[]
        f['splitPolicy']['allSplit']=True
        self.assertEqual(m.report(f)['repository']['strictSplitAdmission'],'eligible')
        self.assertIn('full validation',m.render(m.report(f)))

    def test_bad_inventory(self):
        changes=[('constructor','invented'),('compliant',1),('compliant',False),
                 ('failure','imaginary'),('selectedBase',False),('namespace','unknown'),('status',None)]
        for key,val in changes:
            with self.subTest(key=key,val=val):
                f=facts(); f['rows'][2][key]=val
                with self.assertRaises(m.Invalid):m.report(f)
        f=facts(); f['rows'].append(f['rows'][0])
        with self.assertRaisesRegex(m.Invalid,'duplicate'):m.report(f)

    def test_malformed_schemas_and_latest(self):
        for key,val in [('schema',1),('rows',{}),('source',[]),('system',None)]:
            f=facts();f[key]=val
            with self.assertRaises(m.Invalid):m.report(f)
        for job in ['missing','x_1','z_1']:
            f=facts();f['latest']['families']['x']['job']=job
            with self.assertRaises(m.Invalid):m.report(f)


class WorkflowTests(unittest.TestCase):
    def test_pause_accepted_pending_hold_gate_separation(self):
        r=m.report(facts(),'x',progress()); w=r['workflow']
        self.assertEqual(w['status'],'paused')
        self.assertEqual(w['binding']['state'],'matching-source')
        self.assertEqual(w['accepted']['acceptedOlderPorts'],12)
        self.assertEqual(w['pendingBatches'][0]['selectedReleases'],4)
        self.assertEqual(w['pendingBatches'][0]['withoutCompilation'],3)
        self.assertEqual(w['holds'][0]['count'],2)
        self.assertEqual(w['gates']['CI'],'OFF')
        self.assertIsNone(w['gates']['splitAudit'])
        self.assertNotIn('secret',json.dumps(w))
        self.assertIn('acceptedOlderPorts=12',m.render(r))
        self.assertIn('sourceAccepted=false',m.render(r))
        self.assertIn('R2=ABI pending',m.render(r))

    def test_binding_different_and_unbound(self):
        p=progress();p['workingBaseline']['head']='different'
        self.assertEqual(m.report(facts(),external=p)['workflow']['binding']['state'],'different-source')
        p['workingBaseline']={}
        self.assertEqual(m.report(facts(),external=p)['workflow']['binding']['state'],'unbound')

    def test_missing_and_zero_are_distinct(self):
        w=m.report(facts(),external={'schema':1})['workflow']
        self.assertIsNone(w['accepted']['acceptedOlderPorts'])
        self.assertIsNone(w['status'])
        self.assertIsNone(w['holds'])
        self.assertIsNone(w['pendingBatches'])
        p=progress();p['olderRecipeMigration']={k:0 for k in p['olderRecipeMigration']}
        self.assertEqual(m.report(facts(),external=p)['workflow']['accepted']['acceptedOlderPorts'],0)

    def test_bad_counts_and_partial_counter_accounting(self):
        for value in [True,-1,1.5,'3',[]]:
            for field in progress()['olderRecipeMigration']:
                p=progress();p['olderRecipeMigration'][field]=value
                with self.subTest(value=value,field=field),self.assertRaises(m.Invalid):m.report(facts(),external=p)
        p=progress();p['olderRecipeMigration']['ordinaryReleasesPortedThisPass']=13
        with self.assertRaisesRegex(m.Invalid,'do not sum'):m.report(facts(),external=p)
        del p['olderRecipeMigration']['evaluationOnlyThisPass']
        self.assertIsNone(m.report(facts(),external=p)['workflow']['accepted']['withoutRepresentativeCompilation'])

    def test_malformed_workflow(self):
        for p in [[],{}, {'schema':True}, {'schema':2}, {'schema':1,'ci':False},
                  {'schema':1,'pausedByUser':'paused'}, {'schema':1,'currentWave':'x','waves':{'x':{'sourceAccepted':'false'}}},
                  {'schema':1,'pendingDownstreamQualification':{'x':{'count':True}}}]:
            with self.subTest(p=p),self.assertRaises(m.Invalid):m.report(facts(),external=p)

    def test_contradictory_current_batch_counts(self):
        changes = [
            {'implementedReleases': 9},
            {'representativesBuilt': 8},
            {'preflightEvaluationOnly': ['a','b','c','d','e']},
            {'implementedReleases': 0},
            {'representativesBuilt': 2},
        ]
        for values in changes:
            p=progress(); p['waves']['next'].update(values)
            with self.subTest(values=values),self.assertRaises(m.Invalid):m.report(facts(),external=p)

    def test_partial_current_batch_counts_preserve_unknowns(self):
        for field in ('selectedReleases', 'implementedReleases', 'representativesBuilt', 'preflightEvaluationOnly'):
            p=progress(); del p['waves']['next'][field]
            key='withoutCompilation' if field=='preflightEvaluationOnly' else field
            with self.subTest(field=field):
                self.assertIsNone(m.report(facts(),external=p)['workflow']['currentBatch'][key])
        p=progress(); p['waves']['next'].update(selectedReleases=0,implementedReleases=0,
                                               representativesBuilt=0,preflightEvaluationOnly=[])
        batch=m.report(facts(),external=p)['workflow']['currentBatch']
        self.assertEqual([batch[k] for k in ('selectedReleases','implementedReleases',
                                            'representativesBuilt','withoutCompilation')],[0,0,0,0])

    def test_current_batch_does_not_repeat_stale_waves(self):
        p=progress();p['waves']['stale']={'sourceAccepted':False, 'selectedReleases':99}
        w=m.report(facts(),external=p)['workflow']
        self.assertEqual([b['batch'] for b in w['pendingBatches']],['next'])
        del p['waves']['next']['sourceAccepted']
        w=m.report(facts(),external=p)['workflow']
        self.assertIsNone(w['currentBatch']['sourceAccepted'])
        self.assertIsNone(w['pendingBatches'])

    def test_json_duplicate_keys(self):
        import tempfile
        from pathlib import Path
        with tempfile.TemporaryDirectory() as tmp:
            p=Path(tmp)/'bad.json';p.write_text('{"schema":1,"schema":2}')
            with self.assertRaisesRegex(m.Invalid,'duplicate JSON key'):m.load(p)

    def test_arguments_exit_before_manifest_read(self):
        for args in [['--migration','--unknown'],['--family','x'],['--migration','--workflow','relative'],['--migr']]:
            with self.subTest(args=args),patch.object(m,'load',side_effect=AssertionError('unexpected read')):
                with self.assertRaises(SystemExit) as exit:m.main(args)
                self.assertEqual(exit.exception.code,2)
        with patch.object(m,'load',side_effect=AssertionError('unexpected read')):
            with self.assertRaises(SystemExit) as exit:m.main(['--migration','--help'])
            self.assertEqual(exit.exception.code,0)


if __name__=='__main__':unittest.main()

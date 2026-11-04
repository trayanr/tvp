import contextlib
import fcntl
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock

import runner
import progress
import attempts
import verifier
import graph_compare


FAKE_NIX = r'''
import json, os
from pathlib import Path
import sys, time
args=sys.argv[1:]
with open(os.environ['FAKE_COMMANDS'], 'a') as commands:
    commands.write(json.dumps(args)+'\n')
link=Path(args[args.index('--out-link')+1])
plan=json.loads(Path(os.environ['FAKE_PLAN']).read_text())
if any('#testPlans.' in a for a in args):
    link.symlink_to(os.environ['FAKE_PLAN'])
    sys.exit(0)
print('@nix '+json.dumps({'action':'start','id':7,'type':105,'fields':[plan['jobs'][0]['drv']]}), file=sys.stderr, flush=True)
time.sleep(float(os.environ.get('FAKE_DELAY','0')))
failed=False
targets=set(args)
for job in plan['jobs']:
    if job['name']==os.environ.get('FAKE_FAILURE'):
        failed=True
        continue
    for item in [job]+job.get('tests',[]):
        # Substituting a cached aggregate/suite restores selected links only.
        # Unreferenced siblings require an explicit all-outputs build target.
        outputs=item['outputs'] if item['drv']+'^*' in targets else item['outputs'][:1]
        for out in outputs:
            Path(out).write_text('ok')
print('@nix '+json.dumps({'action':'stop','id':7}), file=sys.stderr, flush=True)
if not failed:
    aggregate=Path(os.environ['FAKE_PLAN']).with_name('aggregate')
    aggregate.write_text('complete')
    link.symlink_to(aggregate)
sys.exit(1 if failed else 0)
'''

FAKE_STORE = r'''
from pathlib import Path
import os, sys, time
args=sys.argv[1:]
if '--check-validity' in args:
    missing=[p for p in sys.stdin.read().splitlines() if not Path(p).exists()]
    print('\n'.join(missing), end='\n' if missing else '')
    sys.exit(1 if missing else 0)
if '--add-root' in args:
    if '--stdin' in args:
        time.sleep(float(os.environ.get('FAKE_ROOT_DELAY','0')))
        if os.environ.get('FAKE_ROOT_FAILURE'):
            sys.exit(1)
        once=os.environ.get('FAKE_ROOT_FAIL_ONCE')
        if once and not Path(once).exists():
            Path(once).touch()
            sys.exit(1)
    link=Path(args[args.index('--add-root')+1])
    paths=sys.stdin.read().splitlines() if '--stdin' in args else [args[-1]]
    if any(not Path(path).exists() for path in paths):
        sys.exit(1)
    for i,path in enumerate(paths):
        root=link if i==0 else link.with_name(link.name+'-'+str(i+1))
        root.unlink(missing_ok=True)
        root.symlink_to(path)
'''


class RunnerTests(unittest.TestCase):
    def setUp(self):
        self.temporary=tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root=Path(self.temporary.name)
        self.script=self.root/'app/libexec/tvp-test/runner.py'
        self.script.parent.mkdir(parents=True)
        shutil.copy(runner.__file__, self.script)
        shutil.copy(progress.__file__, self.script.with_name('progress.py'))
        shutil.copy(attempts.__file__, self.script.with_name('attempts.py'))
        shutil.copy(verifier.__file__, self.script.with_name('verifier.py'))
        shutil.copy(graph_compare.__file__, self.script.with_name('graph_compare.py'))
        binaries=self.root/'bin'
        binaries.mkdir()
        for name, code in [('nix',FAKE_NIX),('nix-store',FAKE_STORE)]:
            path=binaries/name
            path.write_text('#!'+sys.executable+'\n'+code)
            path.chmod(0o755)
        self.plan={'schema':1,'aggregate':'/fake/all.drv','source':'/fake/frozen-source',
                   'skipped':[{'name':'declared-broken','reason':'period libc needed'}],
                   'jobs':[{'name':n,'drv':'/fake/'+n+'.drv','outputs':[str(self.root/(n+'.out'))]}
                           for n in ['first','second']]}
        self.plan_file=self.root/'fixture.json'
        self.plan_file.write_text(json.dumps(self.plan))
        self.commands_file=self.root/'commands.jsonl'
        self.env=dict(os.environ,PATH=str(binaries)+os.pathsep+os.environ['PATH'],FAKE_PLAN=str(self.plan_file),FAKE_COMMANDS=str(self.commands_file))
        self.state=self.root/'state'

    def cli(self,*args):
        return subprocess.run([sys.executable,str(self.script),*args],env=self.env,text=True,capture_output=True)

    def start(self,*args):
        result=self.cli('start','--state-dir',str(self.state),*args)
        self.assertEqual(result.returncode,0,result.stderr)
        self.run=(self.state/'latest').resolve()
        self.addCleanup(self.stop_if_running)

    def stop_if_running(self):
        if hasattr(self,'run') and runner.lease_held(self.run/'worker.lock'):
            self.cli('stop','--run',str(self.run))
            self.wait_done()

    def wait_done(self):
        deadline=time.monotonic()+12
        while time.monotonic()<deadline:
            state=json.loads((self.run/'state.json').read_text())
            if state['phase'] in runner.TERMINAL:
                return state
            time.sleep(0.05)
        self.fail('worker did not finish: '+(self.run/'worker.log').read_text())

    def test_partial_failure_keeps_success_and_reports_failure(self):
        self.env['FAKE_FAILURE']='second'
        self.start()
        # The worker uses its separate materialised run plan.
        self.assertEqual(json.loads((self.run/'plan.json').read_text())['source'],'/fake/frozen-source')
        state=self.wait_done()
        self.assertEqual(state['phase'],'failed')
        self.assertEqual(state['jobs']['first']['status'],'passed')
        self.assertEqual(state['jobs']['second']['status'],'failed-or-blocked')
        self.assertIn(self.plan['jobs'][0]['outputs'][0],
                      [str(p.readlink()) for p in (self.run/'roots').iterdir()])
        self.assertEqual(self.cli('wait','--run',str(self.run)).returncode,1)

    def test_success_distinguishes_preexisting_cache(self):
        Path(self.plan['jobs'][0]['outputs'][0]).write_text('cached')
        self.start()
        state=self.wait_done()
        self.assertEqual(state['phase'],'passed')
        command=json.loads((self.run/'command.json').read_text())
        self.assertIn('--show-trace',command)
        preparation=next(json.loads(line) for line in self.commands_file.read_text().splitlines()
                         if any('#testPlans.' in arg for arg in json.loads(line)))
        self.assertIn('--show-trace',preparation)
        self.assertNotIn('--max-jobs',command)
        self.assertNotIn('--cores',command)
        self.assertTrue(state['jobs']['first']['cachedAtStart'])
        self.assertFalse(state['jobs']['second']['cachedAtStart'])
        self.assertGreaterEqual(state['finishedAt'],state['startedAt'])
        self.assertEqual(self.cli('wait','--run',str(self.run)).returncode,0)

    def test_cached_aggregate_restores_unreferenced_output_siblings(self):
        selected=self.plan['jobs'][0]
        selected['outputs'].append(str(self.root/'unreferenced-primary'))
        # Repeated occurrences must not add repeated build targets.
        repeated=dict(selected,name='repeated',outputs=list(selected['outputs']))
        self.plan['jobs'].append(repeated)
        nested={'name':'nested','drv':'/fake/nested.drv',
                'outputs':[str(self.root/'nested-secondary'),str(self.root/'nested-primary')]}
        self.plan['jobs'][1]['tests']=[nested]
        self.plan_file.write_text(json.dumps(self.plan))
        self.start()
        state=self.wait_done()
        self.assertEqual(state['phase'],'passed',state)
        targets=[arg for arg in json.loads((self.run/'command.json').read_text()) if arg.endswith('^*')]
        self.assertEqual(targets,[self.plan['aggregate']+'^*',selected['drv']+'^*',nested['drv']+'^*'])
        self.assertTrue(all(Path(out).exists() for item in [selected,nested] for out in item['outputs']))
        command=json.loads((self.run/'command.json').read_text())
        self.assertEqual(command[command.index('--out-link')+1],str(self.run/'roots/build'))
        self.assertEqual((self.run/'result').resolve(),self.plan_file.with_name('aggregate'))
        self.assertTrue((self.run/'roots/build').is_symlink())
        self.assertEqual(list(self.run.glob('result-*')),[])

    def test_partial_suite_requests_nested_multioutputs(self):
        nested={'name':'nested','drv':'/fake/nested.drv',
                'outputs':[str(self.root/'nested-secondary'),str(self.root/'nested-primary')]}
        self.plan['jobs'][0]['tests']=[nested]
        self.plan_file.write_text(json.dumps(self.plan))
        self.start('--only','first')
        self.assertEqual(self.wait_done()['phase'],'passed')
        targets=[arg for arg in json.loads((self.run/'command.json').read_text()) if arg.endswith('^*')]
        self.assertEqual(targets,['/fake/first.drv^*','/fake/nested.drv^*'])

    def test_single_output_targets_keep_the_aggregate_first(self):
        self.assertEqual(runner.build_targets(self.plan,True),[self.plan['aggregate']])
        self.assertEqual(runner.build_targets(self.plan,False),[job['drv'] for job in self.plan['jobs']])

    def test_json_start_identifies_exact_frozen_run(self):
        result=self.cli('start','--state-dir',str(self.state),'--json')
        self.assertEqual(result.returncode,0,result.stderr)
        launched=json.loads(result.stdout)
        self.run=Path(launched['run'])
        self.addCleanup(self.stop_if_running)
        self.assertEqual(launched['runner'],str(self.run/'runner/bin/tvp-test'))
        self.assertEqual(launched['source'],self.plan['source'])
        self.assertEqual(launched['suites'],2)
        # The returned identity remains valid after the convenience alias moves.
        (self.state/'latest').unlink()
        (self.state/'latest').symlink_to(self.root/'different-run')
        self.assertEqual(self.wait_done()['phase'],'passed')
        self.assertEqual(self.cli('status','--run',str(self.run),'--json').returncode,0)

    def test_status_identifies_the_selected_local_run(self):
        self.start()
        self.wait_done()
        result=self.cli('status','--state-dir',str(self.state))
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertIn('Run: '+str(self.run),result.stdout)

    def test_missing_local_state_explains_how_to_select_a_run(self):
        result=self.cli('status','--state-dir',str(self.state))
        self.assertNotEqual(result.returncode,0)
        self.assertIn('No local validation run',result.stderr)
        self.assertIn('--state-dir DIR or --run PATH',result.stderr)
        self.assertIn('Buildbot',result.stderr)

    def test_duplicate_start_and_stop(self):
        self.env['FAKE_DELAY']='10'
        self.start()
        second=self.cli('start','--state-dir',str(self.state))
        self.assertNotEqual(second.returncode,0)
        self.assertIn('already running',second.stderr)
        deadline=time.monotonic()+5
        while not json.loads((self.run/'state.json').read_text()).get('pid'):
            self.assertLess(time.monotonic(),deadline)
            time.sleep(0.02)
        self.assertEqual(self.cli('stop','--run',str(self.run)).returncode,0)
        self.assertEqual(self.wait_done()['phase'],'cancelled')

    def test_unknown_selection_is_rejected(self):
        result=self.cli('start','--state-dir',str(self.state),'--only','missing')
        self.assertNotEqual(result.returncode,0)
        self.assertIn('Unknown suites',result.stderr)

    def test_owner_exit_cancels_detached_work_and_keeps_completed_outputs(self):
        self.env['FAKE_DELAY']='30'
        completed=Path(self.plan['jobs'][0]['outputs'][0])
        completed.write_text('cached')
        owner_path=self.root/'owner.lock'
        with owner_path.open('a') as owner:
            fcntl.flock(owner,fcntl.LOCK_EX)
            self.start('--owner-lock',str(owner_path))
            deadline=time.monotonic()+5
            while not json.loads((self.run/'state.json').read_text()).get('active'):
                self.assertLess(time.monotonic(),deadline)
                time.sleep(0.02)
            self.assertNotEqual(json.loads((self.run/'state.json').read_text())['phase'],'cancelled')
        state=self.wait_done()
        self.assertEqual(state['phase'],'cancelled')
        self.assertEqual(state['cancelReason'],'Controlling process exited')
        self.assertEqual(completed.read_text(),'cached')
        self.assertEqual(state['jobs']['first']['status'],'passed')
        self.assertEqual(state['jobs']['second']['status'],'cancelled')
        self.assertIn(str(completed),[str(p.readlink()) for p in (self.run/'roots').iterdir()])

    def test_cancellation_during_rooting_keeps_completed_outputs_protected(self):
        self.env['FAKE_ROOT_DELAY']='0.5'
        for job in self.plan['jobs']:Path(job['outputs'][0]).touch()
        self.start()
        deadline=time.monotonic()+5
        while json.loads((self.run/'state.json').read_text()).get('operation')!='registering-roots':
            self.assertLess(time.monotonic(),deadline)
            time.sleep(0.02)
        self.assertEqual(self.cli('stop','--run',str(self.run)).returncode,0)
        self.assertEqual(self.wait_done()['phase'],'cancelled')
        self.assertTrue({j['outputs'][0] for j in self.plan['jobs']}.issubset(
            {str(p.readlink()) for p in (self.run/'roots').iterdir()}))

    def test_root_registration_failure_cannot_report_a_successful_run(self):
        self.env['FAKE_ROOT_FAILURE']='1'
        self.start()
        self.assertEqual(self.wait_done()['phase'],'error')
        self.assertEqual(self.cli('wait','--run',str(self.run)).returncode,1)

    def test_root_failure_in_linked_retry_cannot_make_original_run_green(self):
        self.env['FAKE_FAILURE']='second'
        self.start()
        self.assertEqual(self.wait_done()['phase'],'failed')
        original=self.run
        self.env.pop('FAKE_FAILURE')
        self.env['FAKE_ROOT_FAILURE']='1'
        result=self.cli('start','--state-dir',str(self.root/'retry-state'),
                        '--only','second','--retry-of',str(original))
        self.assertEqual(result.returncode,0,result.stderr)
        self.run=(self.root/'retry-state/latest').resolve()
        self.assertEqual(self.wait_done()['phase'],'error')
        self.assertEqual(self.cli('wait','--run',str(original)).returncode,1)
        combined=json.loads(self.cli('status','--run',str(original),'--json').stdout)
        self.assertEqual(combined['phase'],'error')
        self.assertTrue(combined['retryErrors'])

    def test_final_root_retry_clears_a_recovered_monitor_error(self):
        self.env['FAKE_ROOT_FAIL_ONCE']=str(self.root/'root-failed-once')
        for job in self.plan['jobs']:Path(job['outputs'][0]).touch()
        self.start()
        state=self.wait_done()
        self.assertTrue(Path(self.env['FAKE_ROOT_FAIL_ONCE']).exists())
        self.assertEqual(state['phase'],'passed',state)
        self.assertNotIn('monitorError',state)

    def test_unheld_owner_lock_cannot_launch_detached_work(self):
        result=self.cli('start','--state-dir',str(self.state),'--owner-lock',str(self.root/'unheld.lock'))
        self.assertNotEqual(result.returncode,0)
        self.assertIn('must hold --owner-lock',result.stderr)
        self.assertFalse(self.state.exists())

    def test_activity_is_optional_and_interrupted_state_is_visible(self):
        active={};log=io.StringIO()
        runner.apply_event(active,{'action':'future-format','type':999},log)
        runner.apply_event(active,{'action':'start','id':1,'type':105,'fields':['/fake/compiler.drv']},log)
        self.assertIn('1',active)
        runner.apply_event(active,{'action':'stop','id':1},log)
        self.assertEqual(active,{})
        run=self.root/'interrupted';run.mkdir()
        runner.write_json(run/'state.json',{'phase':'running','startedAt':time.time(),'jobs':{}})
        with contextlib.redirect_stdout(io.StringIO()):
            state=runner.status(run)
        self.assertEqual(state['phase'],'interrupted')

    def test_debug_cache_traffic_is_not_persisted(self):
        self.assertFalse(runner.useful_event({'action':'start','type':109},{}))
        self.assertFalse(runner.useful_event({'action':'msg','level':6},{}))
        self.assertTrue(runner.useful_event({'action':'msg','level':0},{}))
        self.assertTrue(runner.useful_event({'action':'start','type':105},{}))
        self.assertTrue(runner.useful_event({'action':'start','type':108},{}))
        self.assertTrue(runner.useful_event({'action':'stop','id':7},{'7':{}}))

    def test_successful_retry_replaces_old_failure_and_wait_exit_status(self):
        self.env['FAKE_FAILURE']='second'
        self.start()
        self.assertEqual(self.wait_done()['phase'],'failed')
        original=self.run
        self.env.pop('FAKE_FAILURE')
        self.plan['jobs'][1]['drv']='/fake/second-fixed.drv'
        self.plan['jobs'][1]['outputs']=[str(self.root/'second-fixed.out')]
        self.plan_file.write_text(json.dumps(self.plan))
        result=self.cli('start','--state-dir',str(self.root/'retry-state'),
                        '--only','second','--retry-of',str(original))
        self.assertEqual(result.returncode,0,result.stderr)
        self.run=(self.root/'retry-state/latest').resolve()
        self.assertEqual(self.wait_done()['phase'],'passed')
        current=json.loads(self.cli('status','--run',str(original),'--json').stdout)
        self.assertEqual(current['phase'],'passed')
        self.assertEqual(current['counts'],{'passed':2})
        self.assertEqual(current['jobs']['second']['attempt'],str(self.run))
        self.assertEqual(current['attempts'][0]['returnCode'],1)
        self.assertEqual(self.cli('wait','--run',str(original)).returncode,0)
        history=json.loads(self.cli('status','--run',str(original),'--attempt-only','--json').stdout)
        self.assertEqual(history['jobs']['second']['status'],'failed-or-blocked')

    def retry_fixture(self, name, statuses, start=1):
        run=self.root/name;run.mkdir()
        plan={'system':'x86_64-linux','jobs':[
            {'name':n,'drv':'/nix/store/'+name+'-'+n+'.drv','outputs':['/fake/'+name+'-'+n],
             'tests':[]} for n in statuses]}
        (run/'plan.json').write_text(json.dumps(plan))
        state={'run':str(run),'phase':'failed' if 'failed-or-blocked' in statuses.values() else 'running',
               'startedAt':start,'counts':{},'jobs':{
                   n:{'status':value,'cachedAtStart':False,'tests':{value:1}} for n,value in statuses.items()},
               'reportedFailedDerivations':[job['drv'] for job in plan['jobs']
                                            if statuses[job['name']]=='failed-or-blocked']}
        return run,state

    def test_retry_pending_does_not_claim_pass_or_hide_unrelated_failure(self):
        original,base=self.retry_fixture('original',{'first':'failed-or-blocked','second':'failed-or-blocked'})
        retry,current=self.retry_fixture('retry',{'first':'pending'},2)
        # An independent run is never treated as a retry implicitly.
        self.assertEqual(attempts.combine(original,base,lambda _:current)['jobs']['first']['status'],
                         'failed-or-blocked')
        attempts.register_retry(original,retry)
        result=attempts.combine(original,base,lambda _:current)
        self.assertEqual(result['jobs']['first']['status'],'pending')
        self.assertEqual(result['jobs']['second']['status'],'failed-or-blocked')
        self.assertEqual(result['reportedFailedDerivations'],['/nix/store/original-second.drv'])

    def test_latest_failed_retry_remains_visible(self):
        original,base=self.retry_fixture('original',{'first':'failed-or-blocked'})
        good,passed=self.retry_fixture('good',{'first':'passed'},2)
        bad,failed=self.retry_fixture('bad',{'first':'failed-or-blocked'},3)
        attempts.register_retry(original,good)
        attempts.register_retry(original,bad)
        result=attempts.combine(original,base,lambda path: {good:passed,bad:failed}[path])
        self.assertEqual(result['jobs']['first']['status'],'failed-or-blocked')
        self.assertEqual(result['reportedFailedDerivations'],['/nix/store/bad-first.drv'])

    def test_cancelled_interrupted_and_global_failed_retry_never_become_green(self):
        for phase in ['cancelled','interrupted','failed']:
            with self.subTest(phase=phase):
                original,base=self.retry_fixture('original-'+phase,{'first':'failed-or-blocked'})
                retry,current=self.retry_fixture('retry-'+phase,{'first':'passed'},2)
                current['phase']=phase
                attempts.register_retry(original,retry)
                self.assertEqual(attempts.combine(original,base,lambda _:current)['phase'],phase)

    def test_fully_superseded_infrastructure_error_does_not_block_good_retry(self):
        original,base=self.retry_fixture('original-error',{'first':'passed'})
        base.update(phase='error',error='rooting failed',monitorError='old root query failure')
        retry,current=self.retry_fixture('good-retry',{'first':'passed'},2)
        current['phase']='passed'
        attempts.register_retry(original,retry)
        result=attempts.combine(original,base,lambda _:current)
        self.assertEqual(result['phase'],'passed')
        self.assertNotIn('error',result)
        self.assertNotIn('monitorError',result)

    def test_combined_progress_reports_the_active_retry_operation(self):
        original,base=self.retry_fixture('original-progress',{'first':'failed-or-blocked'})
        base['operation']='checking-outputs'
        retry,current=self.retry_fixture('retry-progress',{'first':'pending'},2)
        current.update(operation='registering-roots',rooting={'completed':2,'total':3})
        attempts.register_retry(original,retry)
        result=attempts.combine(original,base,lambda _:current)
        self.assertEqual(result['operation'],'registering-roots')
        self.assertEqual(result['rooting'],{'completed':2,'total':3})

    def test_retry_rejects_cycles_and_platform_mismatch(self):
        original,_=self.retry_fixture('original',{'first':'pending'})
        retry,_=self.retry_fixture('retry',{'first':'pending'},2)
        attempts.register_retry(original,retry)
        with self.assertRaisesRegex(RuntimeError,'parent'):
            attempts.register_retry(retry,original)
        plan=json.loads((retry/'plan.json').read_text());plan['system']='aarch64-linux'
        (retry/'plan.json').write_text(json.dumps(plan))
        with self.assertRaisesRegex(RuntimeError,'platform'):
            attempts.register_retry(original,retry)

    def test_successful_retry_does_not_hide_unrelated_cancellation(self):
        original,base=self.retry_fixture('original',{'first':'cancelled','second':'cancelled'})
        base['phase']='cancelled'
        retry,current=self.retry_fixture('retry',{'first':'passed'},2)
        current['phase']='passed'
        attempts.register_retry(original,retry)
        result=attempts.combine(original,base,lambda _:current)
        self.assertEqual(result['phase'],'cancelled')
        self.assertEqual(result['counts'],{'passed':1,'cancelled':1})

    def test_successful_retry_does_not_hide_unrelated_infrastructure_error(self):
        original,base=self.retry_fixture('original',{'first':'pending','second':'pending'})
        base.update(phase='error',error='store query failed')
        retry,current=self.retry_fixture('retry',{'first':'passed'},2)
        current['phase']='passed'
        attempts.register_retry(original,retry)
        result=attempts.combine(original,base,lambda _:current)
        self.assertEqual(result['phase'],'error')
        self.assertEqual(result['jobs']['second']['status'],'pending')

    def observe_fixture(self, tests):
        run=self.root/'observed';run.mkdir();(run/'roots').mkdir()
        plan={'jobs':[{'name':'suite','drv':'/fake/suite.drv',
                       'outputs':[str(self.root/'summary.out')], 'tests':tests}]}
        state={'jobs':{'suite':{'status':'pending'}}}
        return run,plan,state

    def test_suite_passes_before_summary_is_built(self):
        output=self.root/'test.out';output.write_text('passed')
        run,plan,state=self.observe_fixture([
            {'name':'digest','drv':'/fake/digest.drv','outputs':[str(output)]}])
        with mock.patch.dict(os.environ,self.env):
            progress.observe(plan,state,run)
        self.assertFalse((self.root/'summary.out').exists())
        self.assertEqual(state['jobs']['suite']['status'],'passed')
        self.assertEqual(state['testCounts']['passed'],1)
        self.assertIn(str(output),[str(p.readlink()) for p in (run/'roots').iterdir()])

    def test_root_batches_deduplicate_share_and_skip_already_protected_outputs(self):
        run,plan,state=self.observe_fixture([])
        paths=[]
        for i in range(2050):
            path=self.root/('output-'+str(i));path.touch();paths.append(str(path))
        protected=set();updates=[]
        with mock.patch.dict(os.environ,self.env), mock.patch.object(
                progress.subprocess,'run',wraps=subprocess.run) as command:
            progress.root_paths(run,paths+paths[:10],protected,on_progress=lambda *p:updates.append(p))
            self.assertEqual(command.call_count,3)
            for call in command.call_args_list:
                args=call.args[0]
                self.assertIn('--stdin',args)
                self.assertEqual(args[args.index('--max-jobs')+1],'0')
                self.assertIn(['--option','builders',''],[args[i:i+3] for i in range(len(args)-2)])
                self.assertIn(['--option','substituters',''],[args[i:i+3] for i in range(len(args)-2)])
            progress.root_paths(run,paths,protected)
            self.assertEqual(command.call_count,3)
        self.assertEqual(protected,set(paths))
        self.assertEqual(updates,[(0,2050),(1024,2050),(2048,2050),(2050,2050)])
        self.assertEqual({str(p.readlink()) for p in (run/'roots').iterdir()},set(paths))

    def test_root_failure_is_not_marked_protected_and_retry_is_stable(self):
        run,_,_=self.observe_fixture([])
        output=self.root/'good';output.touch();protected=set();prefixes=[]
        def partial(args,**kwargs):
            prefixes.append(args[args.index('--add-root')+1])
            Path(prefixes[-1]).symlink_to(output)
            raise subprocess.CalledProcessError(1,args)
        with mock.patch.object(progress.subprocess,'run',side_effect=partial):
            with self.assertRaises(subprocess.CalledProcessError):
                progress.root_paths(run,[str(output)],protected)
        self.assertEqual(protected,set())
        with mock.patch.dict(os.environ,self.env), mock.patch.object(
                progress.subprocess,'run',wraps=subprocess.run) as command:
            progress.root_paths(run,[str(output)],protected)
            self.assertEqual(command.call_args.args[0][2],prefixes[0])
        self.assertEqual(protected,{str(output)})

    def test_missing_root_target_fails_without_claiming_protection(self):
        run,_,_=self.observe_fixture([]);protected=set()
        with mock.patch.dict(os.environ,self.env):
            with self.assertRaises(subprocess.CalledProcessError):
                progress.root_paths(run,[str(self.root/'missing')],protected)
        self.assertEqual(protected,set())
        self.assertEqual(list((run/'roots').iterdir()),[])

    def test_wait_prints_changes_and_a_single_heartbeat_without_store_queries(self):
        base={'phase':'running','operation':'building','elapsedSeconds':0,'counts':{'passed':0,'pending':2},
              'jobs':{name:{'status':'pending','cachedAtStart':True} for name in ['first','second']}}
        states=[dict(base,elapsedSeconds=t) for t in [0,1,61]]
        rooted=dict(base,operation='registering-roots',rooting={'completed':1,'total':2},elapsedSeconds=62)
        finished=dict(rooted,phase='passed',elapsedSeconds=64,counts={'passed':2},
                      jobs={name:{'status':'passed','cachedAtStart':True} for name in ['first','second']})
        states.extend([rooted,dict(rooted,elapsedSeconds=63),finished])
        with mock.patch.object(runner,'status',side_effect=states) as status, \
             mock.patch.object(runner.time,'monotonic',side_effect=[0,1,61,62,63,64]), \
             mock.patch.object(runner.time,'sleep'), contextlib.redirect_stdout(io.StringIO()) as console:
            self.assertEqual(runner.wait(self.root),0)
        text=console.getvalue()
        self.assertEqual(text.count('Run:'),3)
        self.assertEqual(text.count('Still building'),1)
        self.assertIn('Registering GC roots: 1/2',text)
        self.assertNotIn('resolving dependencies',text)
        for call in status.call_args_list:self.assertFalse(call.kwargs['inspect_store'])

    def test_snapshot_status_skips_observation_and_preserves_terminal_failure(self):
        run,_,_=self.observe_fixture([])
        (run/'plan.json').write_text(json.dumps({'jobs':[],'skipped':[]}))
        (run/'state.json').write_text(json.dumps({'phase':'failed','startedAt':0,'finishedAt':1,'jobs':{}}))
        with mock.patch.object(runner,'observe') as observe:
            self.assertEqual(runner.status(run,as_json=None,inspect_store=False)['phase'],'failed')
            observe.assert_not_called()

    def test_live_failure_is_deduplicated_and_success_wins(self):
        good=self.root/'good.out';good.write_text('passed')
        run,plan,state=self.observe_fixture([
            {'name':'good','drv':'/nix/store/good.drv','outputs':[str(good)]},
            {'name':'bad','drv':'/nix/store/bad.drv','outputs':[str(self.root/'bad.out')]}])
        log=run/'nix.log'
        log.write_text("error: Cannot build '/nix/store/bad.drv'.\n"*2+
                       "error: Cannot build '/nix/store/good.drv'.\n"+
                       "error: Cannot build '/nix/store/incomplete")
        with mock.patch.dict(os.environ,self.env):
            progress.observe(plan,state,run,root_completed=False)
            self.assertEqual(state['jobs']['suite']['status'],'failed-or-blocked')
            self.assertEqual(state['testCounts'],
                             {'passed':1,'failed-or-blocked':1,'pending':0,'cancelled':0})
            self.assertEqual(len(state['reportedFailedDerivations']),2)
            with log.open('a') as stream:
                stream.write(".drv'.\n")
            progress.observe(plan,state,run,root_completed=False)
        self.assertEqual(len(state['reportedFailedDerivations']),3)

    def test_pending_and_cancelled_are_distinct_from_reported_failures(self):
        run,plan,state=self.observe_fixture([
            {'name':'pending','drv':'/fake/pending.drv','outputs':[str(self.root/'absent')]}])
        with mock.patch.dict(os.environ,self.env):
            progress.observe(plan,state,run,root_completed=False)
            self.assertEqual(state['jobs']['suite']['status'],'pending')
            state['cancelled']=True
            progress.observe(plan,state,run,final=True,root_completed=False)
        self.assertEqual(state['jobs']['suite']['status'],'cancelled')

    def test_failed_summary_does_not_mark_pending_independent_tests_failed(self):
        run,plan,state=self.observe_fixture([
            {'name':'pending','drv':'/fake/pending.drv','outputs':[str(self.root/'absent')]}])
        plan['jobs'][0]['drv']='/nix/store/summary.drv'
        (run/'nix.log').write_text("error: Cannot build '/nix/store/summary.drv'.\n")
        with mock.patch.dict(os.environ,self.env):
            progress.observe(plan,state,run,root_completed=False)
        self.assertEqual(state['jobs']['suite']['status'],'failed-or-blocked')
        self.assertEqual(state['testCounts']['failed-or-blocked'],0)
        self.assertEqual(state['testCounts']['pending'],1)

    def test_legacy_plan_recovers_members_and_caches_without_reevaluation(self):
        for version in [3,4]:
            run=self.root/str(version);run.mkdir()
            batch='/nix/store/'+'a'*32+'-tvp-tests-example.drv'
            child='b'*32+'-example-digest.drv'
            output='/nix/store/'+'c'*32+'-example-digest'
            plan={'jobs':[{'name':'example','drv':batch,
                          'outputs':['/nix/store/'+'d'*32+'-tvp-tests-example']}]}
            drv={'env':{'buildCommand':f'ln -s {output} digest\n'}}
            if version==3:
                drv['inputDrvs']={'/nix/store/'+child:['out']}
                document={batch:drv}
            else:
                drv['inputs']={'drvs':{child:{'outputs':['out']}}}
                document={'version':4,'derivations':{Path(batch).name:drv}}
            result=subprocess.CompletedProcess([],0,json.dumps(document),'')
            with mock.patch.object(progress.subprocess,'run',return_value=result) as query:
                jobs=progress.members(plan,run)
                self.assertEqual(jobs[0]['tests'],[
                    {'name':'digest','drv':'/nix/store/'+child,'outputs':[output]}])
                self.assertEqual(progress.members(plan,run),jobs)
                self.assertEqual(query.call_count,1)


if __name__=='__main__':
    unittest.main()

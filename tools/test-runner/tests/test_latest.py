"""Protocol tests use finite fake builders; never realize catalogue packages."""

import contextlib
import copy
import fcntl
import io
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

import latest
import latest_graph as g
import latest_supervisor as s
from latest_worker import Worker


def drv(name):
    return '/nix/store/' + 'a' * 32 + '-' + name + '.drv'


def node(name, outputs, deps=(), heavy=False):
    return dict(name=name, heavy=heavy, system='x86_64-linux',
                outputs={k: {'path': v} for k, v in outputs.items()},
                inputDrvs={d: {'outputs': list(o), 'dynamicOutputs': {}} for d, o in deps})


class Fixture(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.run = Path(self.tmp.name)
        (self.run / 'roots').mkdir()
        self.attempt = self.run / 'attempts/001'
        self.attempt.mkdir(parents=True)
        self.outputs = {n: str(self.run / n) for n in ('app', 'dev', 'batch', 'test', 'test-dev', 'aggregate', 'source')}
        self.ids = {n: drv(n) for n in ('gcc', 'llvm', 'test', 'batch', 'aggregate')}
        a, b, t, batch, all_ = [self.ids[n] for n in ('gcc', 'llvm', 'test', 'batch', 'aggregate')]
        o = self.outputs
        self.nodes = {
            a: node('gcc-1', {'out': o['app'], 'dev': o['dev']}, heavy=True),
            b: node('llvm-1', {'out': o['app'] + '-llvm'}, [(a, ['out', 'dev'])], heavy=True),
            t: node('test', {'out': o['test'], 'dev': o['test-dev']}, [(b, ['out'])]),
            batch: node('batch', {'out': o['batch']}, [(t, ['out'])]),
            all_: node('aggregate', {'out': o['aggregate']}, [(batch, ['out']), (t, ['dev']), (a, ['out', 'dev'])]),
        }
        def ident(d):
            outputs = {n: p['path'] for n, p in self.nodes[d]['outputs'].items()}
            return dict(drv=d, out=outputs['out'], outputs=outputs)
        self.d = dict(schema='tvp.latest-descriptor/v1', system='x86_64-linux', source=o['source'],
                      aggregate=ident(all_), batches={'gcc_1': ident(batch) | {'tests': {'compile': ident(t)}}},
                      metadata={'schema': 'tvp.latest-tests/v1', 'families': {
                          'gcc': dict(job='gcc_1', packageDRV=a, jobDRV=batch, outputs=[o['app'], o['dev']])}})
        self.d['requiredOutputs'] = [o[n] for n in ('app', 'dev', 'batch', 'test', 'test-dev')]
        Path(o['source']).mkdir()
        self.state = dict(schema='tvp.latest-state/v1', phase='launching', attempt=1, full=False,
                          startedAt=time.time(), deadlineSeconds=60, cachedOnly=False,
                          source=o['source'], revision='b'*40, tree='c'*40, system='x86_64-linux')
        for name, data in [('state', self.state), ('descriptor', self.d), ('graph', self.nodes), ('bindings', {})]:
            s.save(self.run / (name + '.json'), data)

    def valid(self, paths):
        return {p for p in paths if Path(p).exists()}

    def materialize(self):
        for o in self.nodes.values():
            for value in o['outputs'].values():
                Path(value['path']).mkdir(exist_ok=True)
        for name, batch in self.d['batches'].items():
            (Path(self.d['aggregate']['out']) / name).symlink_to(batch['out'])
            for name, t in batch['tests'].items():
                (Path(batch['out']) / name).symlink_to(t['out'])

    def test_partial_cache_topological_heavy_and_cached_parent_pruning(self):
        requests = g.preparation(self.d, self.nodes, set())
        self.assertEqual([r['drv'] for r in requests], [self.ids['gcc'], self.ids['llvm']])
        self.assertEqual(set(requests[0]['outputs']), {'out', 'dev'})
        # A valid out alone is insufficient when the aggregate demands dev.
        requests = g.preparation(self.d, self.nodes, {self.outputs['app']})
        self.assertEqual(requests[0]['drv'], self.ids['gcc'])
        cached = set(self.d['requiredOutputs']) | {self.outputs['aggregate']}
        self.assertEqual(g.preparation(self.d, self.nodes, cached), [])
        # LLVM is an ancestor, not selected; cached tests don't need to restore it.
        cached.remove(self.outputs['aggregate'])
        self.assertEqual(g.preparation(self.d, self.nodes, cached), [])

    def test_dynamic_unknown_nodes_and_output_paths_are_honest_errors(self):
        child = self.nodes[self.ids['test']]['inputDrvs'][self.ids['llvm']]
        child['dynamicOutputs'] = {'out': {}}
        with self.assertRaisesRegex(ValueError, 'dynamic'):
            g.preparation(self.d, self.nodes, set())
        child['dynamicOutputs'] = {}
        del self.nodes[self.ids['llvm']]
        with self.assertRaisesRegex(ValueError, 'Missing native node'):
            g.preparation(self.d, self.nodes, set())

    def test_exact_siblings_and_links_including_cached_aggregate(self):
        self.materialize()
        with patch.object(g.Store, 'valid', side_effect=self.valid):
            self.assertEqual(g.verify_outputs(self.d, self.nodes)['links'], 2)
            Path(self.outputs['test-dev']).rmdir()
            with self.assertRaisesRegex(ValueError, 'siblings'):
                g.verify_outputs(self.d, self.nodes)
            Path(self.outputs['test-dev']).mkdir()
            link = Path(self.outputs['batch']) / 'compile'
            link.unlink(); link.symlink_to(self.outputs['dev'])
            with self.assertRaisesRegex(ValueError, 'Link target'):
                g.verify_outputs(self.d, self.nodes)

    def test_root_stdout_names_and_actual_targets_not_output_stdout(self):
        self.materialize()
        paths = set(self.d['requiredOutputs'])
        def root_command(command, **kwargs):
            self.assertEqual(command.count('--stdin'), 1)
            self.assertIn('--max-jobs', command)
            prefix = command[command.index('--add-root')+1]
            roots = []
            for i, target in enumerate(kwargs['input'].splitlines()):
                root = Path(prefix + '-' + str(i+1)); root.symlink_to(target); roots.append(str(root))
            return subprocess.CompletedProcess(command, 0, '\n'.join(roots)+'\n', '')
        with patch.object(g.Store, 'valid', side_effect=self.valid), patch.object(g.subprocess, 'run', side_effect=root_command) as command:
            records = g.retain(self.run, paths)
            self.assertEqual(len(records), 5)
            self.assertEqual(command.call_count, 1)
            self.assertEqual({r['target'] for r in records}, paths)
        with patch.object(g.Store, 'valid', return_value=paths), patch.object(g.subprocess, 'run', return_value=subprocess.CompletedProcess([],0,'\n'.join(paths),' ')):
            with self.assertRaisesRegex(ValueError, 'Unowned root'):
                g.retain(self.run, paths)
        with self.assertRaisesRegex(ValueError, 'never --realise'):
            g.retain(self.run, {self.ids['gcc']})

    def test_retry_is_explicit_bounded_and_preserves_failure(self):
        state = self.state | {'workerActive': False, 'phase': 'interrupted'}
        latest.can_retry(self.run, state)
        for phase in ('failed', 'error', 'stopped', 'passed'):
            with self.assertRaises(ValueError):
                latest.can_retry(self.run, state | {'phase': phase})
        with self.assertRaisesRegex(ValueError, 'two'):
            latest.can_retry(self.run, state | {'attempt': 2})
        with self.assertRaisesRegex(ValueError, 'healthy'):
            latest.can_retry(self.run, state | {'workerActive': True})
        s.save(self.run / 'stop.json', {})
        with self.assertRaisesRegex(ValueError, 'stopped'):
            latest.can_retry(self.run, state)

    def test_worker_sequential_requests_fail_fast_terminal_receipt_and_reuse(self):
        commands = []
        def command(worker, phase, targets):
            commands.append((phase, targets))
            if phase == 'heavy':
                d = targets[0].split('^')[0]
                for o in self.nodes[d]['outputs'].values(): Path(o['path']).mkdir(exist_ok=True)
            else:
                self.materialize()
        with patch.object(g.Store, 'valid', side_effect=self.valid), patch('latest_worker.retain', return_value=[]), patch.object(Worker, 'command', command):
            self.assertEqual(Worker(self.run, self.attempt).execute(), 0)
        self.assertEqual([p for p, t in commands], ['heavy','heavy','aggregate'])
        result = s.load(self.attempt / 'result.json')
        self.assertEqual(result['phase'], 'passed')
        self.assertFalse(result['full']); self.assertFalse(result['freshExecutionCertified'])
        self.assertIsNone(result['currentChild'])
        # Same outputs are all valid: no heavy request can be repeated.
        commands.clear()
        with patch.object(g.Store, 'valid', side_effect=self.valid), patch('latest_worker.retain', return_value=[]), patch.object(Worker, 'command', lambda w,p,t: commands.append(p)):
            self.assertEqual(Worker(self.run, self.attempt).execute(), 0)
        self.assertEqual(commands, ['aggregate'])

    def test_worker_genuine_failure_has_no_aggregate_or_retry(self):
        calls = []
        def fail(worker, phase, targets):
            calls.append(targets)
            raise ChildProcessError('compiler failed')
        with patch.object(g.Store, 'valid', side_effect=self.valid), patch('latest_worker.retain', return_value=[]), patch.object(Worker, 'command', fail):
            self.assertEqual(Worker(self.run, self.attempt).execute(), 1)
        self.assertEqual(len(calls), 1)
        self.assertEqual(s.load(self.attempt / 'result.json')['phase'], 'failed')

    def test_worker_command_real_finite_process_receipts_and_default_concurrency(self):
        bin_ = self.run / 'fake-bin'; bin_.mkdir()
        nix = bin_ / 'nix'
        nix.write_text('#!' + sys.executable + '\nimport sys\nprint("build failed")\nsys.exit(17)\n'); nix.chmod(0o755)
        worker = Worker(self.run, self.attempt)
        with patch.dict(os.environ, PATH=str(bin_)):
            with self.assertRaises(ChildProcessError): worker.command('heavy', [self.ids['gcc']+'^out'])
        receipt = s.load(self.attempt / '001-heavy.json')
        self.assertEqual(receipt['returnCode'], 17)
        self.assertTrue(receipt['terminal'])
        self.assertNotIn('--max-jobs', receipt['command']); self.assertNotIn('--cores', receipt['command'])
        self.assertNotIn('--keep-going', receipt['command'])
        self.assertEqual(receipt['command'][receipt['command'].index('keep-going')+1], 'false')

    def test_launch_lock_source_mismatch_and_healthy_resume_never_launch(self):
        s.save(self.run / 'subject.json', {'flake': 'original', 'system': 'x86_64-linux', 'source': self.outputs['source']})
        args = latest.argparse.Namespace(resume=self.run, flake='other', system=None, expect_source=None, retry_interrupted=False)
        with self.assertRaisesRegex(ValueError, 'source argument'):
            latest.start(args)
        args.flake = None
        with patch('latest.snapshot', return_value=self.state | {'workerActive': True}), patch('latest.launch') as launch, contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(latest.start(args), 0)
            launch.assert_not_called()
        with (self.run / 'launch.lock').open('a') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            with self.assertRaises(BlockingIOError): latest.start(args)


    def fake_worker(self, delay=0.15):
        bin_ = self.run / 'bin'
        bin_.mkdir()
        script = bin_ / 'nix'
        script.write_text('#!' + sys.executable + '\n' + r"""
import json,os,sys,time
from pathlib import Path
run=Path(os.environ['FAKE_RUN']); d=json.loads((run/'descriptor.json').read_text()); nodes=json.loads((run/'graph.json').read_text())
a=sys.argv[1:]
if '--check-validity' in a:
    missing=[p for p in sys.stdin.read().splitlines() if not Path(p).exists()]
    print('\n'.join(missing),end='\n' if missing else '');sys.exit(0)
if '--add-root' in a:
    prefix=a[a.index('--add-root')+1]
    for i,p in enumerate(sys.stdin.read().splitlines()):
        root=Path(prefix+'-'+str(i+1))
        if not root.is_symlink():root.symlink_to(p)
        print(root)
    sys.exit(0)
time.sleep(float(os.environ['FAKE_DELAY']))
for target in a:
    if '^' not in target:continue
    drv,outputs=target.split('^');node=nodes[drv]
    for name,o in node['outputs'].items():
        if outputs=='*' or name in outputs.split(','):Path(o['path']).mkdir(exist_ok=True)
    if drv==d['aggregate']['drv']:
        for batchname,b in d['batches'].items():
            for item in [b,*b['tests'].values()]:
                for path in item['outputs'].values():Path(path).mkdir(exist_ok=True)
            (Path(d['aggregate']['out'])/batchname).symlink_to(b['out'])
            for name,t in b['tests'].items():(Path(b['out'])/name).symlink_to(t['out'])
""")
        script.chmod(0o755)
        (bin_ / 'nix-store').symlink_to(script)
        host={'binaries':{},'environment':{'PATH':str(bin_)},'bin':str(bin_), 'foreground':True}
        s.save(self.run/'host.json',host)
        s.save(self.attempt/'launch.json',{'unit':None,'backend':'foreground'})
        env=dict(os.environ,PATH=str(bin_),FAKE_RUN=str(self.run),FAKE_DELAY=str(delay))
        log=(self.run/'worker.log').open('w')
        self.addCleanup(log.close)
        child=subprocess.Popen([sys.executable,str(Path(latest.__file__)),'_worker',str(self.run),str(self.attempt)],
                               env=env,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
        def reap():
            if child.poll() is None: child.terminate()
            child.wait(timeout=10)
        self.addCleanup(reap)
        deadline=time.monotonic()+5
        while time.monotonic()<deadline:
            if s.held(self.run/'worker.lock') and s.load(self.run/'state.json').get('worker'):break
            time.sleep(.01)
        else:self.fail('fake worker did not become healthy: '+(self.run/'worker.log').read_text())
        return child,env

    def test_real_observer_loss_does_not_restart_or_kill_worker(self):
        child,env=self.fake_worker()
        observer=subprocess.Popen([sys.executable,str(Path(latest.__file__)),'wait','--run',str(self.run)],
                                  env=env,stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,text=True,start_new_session=True)
        observed=json.loads(observer.stdout.readline())
        self.assertTrue(observed['workerActive'])
        observer.terminate(); observer.wait(timeout=5); observer.stdout.close()
        self.assertEqual(child.wait(timeout=10),0,(self.run/'worker.log').read_text())
        result=s.load(self.attempt/'result.json')
        self.assertEqual(result['phase'],'passed')
        self.assertEqual(result['attempt'],1)
        s.save(self.run/'subject.json',{k:result[k] for k in ('source','revision','tree','system')})
        with patch.object(g.Store,'valid',side_effect=self.valid):
            self.assertEqual(latest.verify(self.run)['result'],'PASS')
        command_path=Path(result['commandRecord'])
        command=s.load(command_path)
        s.save(command_path,command|{'returnCode':17})
        with self.assertRaisesRegex(ValueError,'aggregate/client'):latest.verify(self.run)
        self.assertEqual(len(list(self.attempt.glob('[0-9]*-heavy.json'))),2)
        self.assertEqual(len(list(self.attempt.glob('[0-9]*-aggregate.json'))),1)

    def test_explicit_stop_reaps_actual_child_and_blocks_resume(self):
        child,_=self.fake_worker(delay=2)
        deadline=time.monotonic()+5
        while time.monotonic()<deadline and not list(self.attempt.glob('[0-9]*-heavy.json')):time.sleep(.01)
        s.stop(self.run)
        self.assertEqual(child.wait(timeout=10),1)
        result=s.load(self.attempt/'result.json')
        self.assertEqual(result['phase'],'stopped')
        self.assertIsNone(result['currentChild'])
        self.assertFalse(list(self.attempt.glob('[0-9]*-aggregate.json')))
        with self.assertRaisesRegex(ValueError,'stopped'):latest.can_retry(self.run,result|{'workerActive':False})

    def test_pid_reuse_stop_and_changed_bindings_refuse_actions(self):
        state=self.state|{'phase':'interrupted','workerActive':False}
        s.save(self.run/'bindings.json',{'descriptor.json':'wrong'})
        with self.assertRaisesRegex(ValueError,'identity differs'):latest.can_retry(self.run,state)
        s.save(self.run/'host.json',{'foreground':True})
        s.save(self.attempt/'launch.json',{'unit':None,'backend':'foreground'})
        reused=s.process(os.getpid())|{'startTicks':'0'}
        with patch('latest_supervisor.snapshot',return_value=self.state|{'workerActive':True,'worker':reused}), patch('latest_supervisor.os.pidfd_open') as pidfd:
            with self.assertRaisesRegex(ValueError,'no longer matches'):s.stop(self.run)
            pidfd.assert_not_called()


class NativeProtocols(unittest.TestCase):
    def native(self):
        key = drv('gcc-1')
        return {'version':4, 'derivations':{key: dict(builder='/bin/sh', system='x86_64-linux',
            env={'name':'gcc-1', 'pname':'gcc', 'version':'1'}, inputs={'srcs':[], 'drvs':{}},
            outputs={'out':{'path': '/nix/store/'+'b'*32+'-gcc-1'}})}}

    def test_native_schema_artifacts_and_real_named_outputs(self):
        document = self.native()
        key = drv('gcc-1')
        self.assertTrue(g.graph(document)[key]['heavy'])
        document['derivations'][key]['outputs']['out']['hash'] = 'sha256:abc'
        self.assertFalse(g.graph(document)[key]['heavy'])
        del document['derivations'][key]['outputs']['out']['hash']
        document['derivations'][key]['env']['name']='gcc-1-upstream-audit'
        self.assertFalse(g.graph(document)[key]['heavy'])
        document['version'] = 99
        with self.assertRaisesRegex(ValueError, 'version 4'): g.graph(document)
        for document in ({'version':4}, {'junk':7}):
            with self.assertRaises(ValueError): g.graph(document)

    def test_malformed_validity_and_command_failure_fail_closed(self):
        for result in (subprocess.CompletedProcess([],0,'/unknown\n',''), subprocess.CompletedProcess([],1,'','bad'), subprocess.CompletedProcess([],2,'','bad')):
            with patch('verifier.subprocess.run', return_value=result), self.assertRaises(ValueError):
                g.Store().valid(['/nix/store/known'])
        with patch('latest_graph.subprocess.run', return_value=subprocess.CompletedProcess([],0,'/nix/store/known\n','')):
            self.assertEqual(g.Store().valid(['/nix/store/known']), set())
        with patch('latest.subprocess.check_output', side_effect=subprocess.CalledProcessError(9,['nix'])):
            with self.assertRaises(subprocess.CalledProcessError): latest.query(['nix'])
        with patch('latest.subprocess.check_output', return_value='{bad'):
            with self.assertRaises(ValueError): latest.query(['nix'])

    def test_pid_reuse_refuses_stop_and_user_bus_failure_is_explicit(self):
        identity=s.process(os.getpid())
        self.assertTrue(s.same_process(identity))
        self.assertFalse(s.same_process(identity | {'startTicks':'0'}))
        with patch('latest_supervisor.shutil.which', return_value='/bin/false'), patch('latest_supervisor.subprocess.run', return_value=subprocess.CompletedProcess([],1,'','no bus')):
            with self.assertRaisesRegex(ValueError, 'explicitly use --foreground'): s.interfaces()

    def test_foreground_boot_gap_is_live_and_launch_records_exact_interpreter(self):
        with tempfile.TemporaryDirectory() as tmp:
            run=Path(tmp);attempt=run/'attempts/001';attempt.mkdir(parents=True)
            config={'bin':str(run), 'binaries':{}, 'environment':{'PATH':'/caller'}}
            s.save(run/'host.json',config)
            s.save(run/'state.json',{'attempt':1,'phase':'launching'})
            child=object()
            with patch('latest_supervisor.subprocess.Popen',return_value=child), patch('latest_supervisor.process',return_value={'pid':123}):
                # Popen exposes a PID immediately, even before worker startup.
                from unittest.mock import Mock
                fake=Mock(pid=123)
                with patch('latest_supervisor.subprocess.Popen',return_value=fake):
                    s.launch(run,attempt,config,True,60,'/frozen/python')
            launch=s.load(attempt/'launch.json')
            self.assertEqual(launch['command'][0],'/frozen/python')
            with patch('latest_supervisor.same_process',return_value=True):
                self.assertTrue(s.snapshot(run)['workerActive'])

    def test_detached_launch_is_finite_no_autorestart_no_observer_binding(self):
        with tempfile.TemporaryDirectory() as tmp:
            run=Path(tmp); attempt=run/'001'; attempt.mkdir()
            config={'bin':str(run), 'binaries':{'systemd-run':'/host/systemd-run'}, 'environment':{'PATH':'/caller'}}
            props={'InvocationID':'bound', 'Id':'unit', 'Restart':'no'}
            with patch('latest_supervisor.subprocess.run', return_value=subprocess.CompletedProcess([],0,'','')) as call, patch('latest_supervisor.unit_show', return_value=props):
                s.launch(run, attempt, config, False, 60, sys.executable)
            args=call.call_args.args[0]
            self.assertIn('--property=Restart=no', args)
            self.assertIn('--property=RuntimeMaxSec=60', args)
            for option in ('--wait','--pipe','--pty'): self.assertNotIn(option,args)
            self.assertEqual(s.load(attempt/'launch.json')['invocationID'], 'bound')


if __name__ == '__main__': unittest.main()

"""Exercise queued cancellation and running stops with a real worker and Nix."""
import argparse
import base64
import http.cookiejar
import json
import os
from pathlib import Path
import shlex
import shutil
import signal
import socket
import subprocess
import tempfile
import time
import urllib.request


SOURCE = Path(__file__).resolve().parents[3]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--runner', required=True, type=Path)
parser.add_argument('--evidence', type=Path)
args = parser.parse_args()
area = (args.evidence or Path(tempfile.mkdtemp(prefix='tvp-cancel-'))).resolve()
area.mkdir(parents=True, exist_ok=True)
runner = args.runner.resolve()
real_nix = shutil.which('nix')


def wait_for(description, check, timeout=35):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            value = check()
            if value:
                return value
        except (OSError, KeyError, json.JSONDecodeError):
            pass
        time.sleep(0.1)
    raise AssertionError('Timed out waiting for ' + description)


def port():
    with socket.socket() as probe:
        probe.bind(('127.0.0.1', 0))
        return probe.getsockname()[1]


repository = area / 'repository'
repository.mkdir()
revision = json.loads((SOURCE / 'flake.lock').read_text())['nodes']['nixpkgs']['locked']['rev']
template = (Path(__file__).parent / 'fixtures/cancellation/flake.nix').read_text()
(repository / 'flake.nix').write_text(template.replace('@revision@', revision).replace('@nonce@', area.name))


def git(*arguments):
    return subprocess.check_output(['git', '-C', str(repository), *arguments], text=True).strip()


git('init', '--quiet', '--initial-branch=master')
git('config', 'user.name', 'CI cancellation fixture')
git('config', 'user.email', 'fixture@invalid')
git('config', 'commit.gpgSign', 'false')
git('add', 'flake.nix')
subprocess.run([real_nix, 'flake', 'lock', str(repository)], check=True)
git('add', 'flake.nix', 'flake.lock')
git('commit', '--quiet', '-m', 'fixture')
head = git('rev-parse', 'HEAD')
secrets = area / 'secrets'
secrets.mkdir()
for name in ['worker-password', 'operator-password']:
    (secrets / name).write_text('test-only')
http_port, worker_port = port(), port()
url = f'http://127.0.0.1:{http_port}'
master, worker = area / 'master', area / 'worker'
worker.mkdir()
settings = {'repository': 'fixture/tvp', 'controller_revision': 'a' * 40,
            'github_enabled': False, 'secrets_directory': str(secrets), 'tools_ref': 'offline-fixture'}
subprocess.run(['buildbot', 'create-master', str(master)], check=True)
(master / 'master.cfg').write_text(
    'import sys\nfrom pathlib import Path\n'
    f'sys.path.insert(0, {str(SOURCE / "ci/buildbot")!r})\n'
    'from configuration import make_config\n'
    f'BuildmasterConfig = make_config({settings!r}, Path({str(SOURCE)!r}))\n'
    f'BuildmasterConfig["www"]["port"] = "tcp:{http_port}:interface=127.0.0.1"\n'
    f'BuildmasterConfig["buildbotURL"] = {url + "/"!r}\n'
    f'BuildmasterConfig["protocols"]["pb"]["port"] = "tcp:{worker_port}:interface=127.0.0.1"\n')
(area / 'worker.tac').write_text(
    'from twisted.application import service\nfrom buildbot_worker.bot import Worker\n'
    'application = service.Application("cancellation-worker")\n'
    f'Worker("127.0.0.1", {worker_port}, "tvp-linux", "test-only", {str(worker)!r}, keepalive=600).setServiceParent(application)\n')
wrappers = area / 'bin'
wrappers.mkdir()
(wrappers / 'nix').write_text(
    '#!' + str(Path(shutil.which('bash')).resolve()) + '\nset -e\n'
    'if [[ "$1" == run ]]; then\n shift\n'
    ' if [[ "$1" == --show-trace ]]; then shift; fi\n shift 2\n'
    f' {shlex.quote(str(runner))} "$@" > "$PWD/test-launch.json"\n'
    f' if [[ -e {shlex.quote(str(area / "hold-launch"))} ]]; then sleep 120; fi\n'
    ' cat "$PWD/test-launch.json"\n exit 0\nfi\n'
    f'exec {shlex.quote(real_nix)} "$@"\n')
(wrappers / 'nix').chmod(0o755)
(area / 'gitconfig').write_text(f'[url "{repository}"]\n\tinsteadOf = https://github.com/fixture/tvp.git\n')
environment = dict(os.environ, PATH=str(wrappers) + os.pathsep + os.environ['PATH'],
                   GIT_CONFIG_GLOBAL=str(area / 'gitconfig'), PYTHONDONTWRITEBYTECODE='1')
opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))


def get(path):
    with opener.open(url + '/api/v2/' + path, timeout=5) as response:
        return json.load(response)


def control(path, method, **params):
    request = urllib.request.Request(url + '/api/v2/' + path,
        data=json.dumps({'jsonrpc': '2.0', 'id': 1, 'method': method, 'params': params}).encode(),
        headers={'Content-Type': 'application/json'})
    with opener.open(request, timeout=10) as response:
        result = json.load(response)
    assert not result.get('error'), result
    return result['result']


def queue():
    result = control('forceschedulers/build-commit', 'force', revision=head,
                     username='operator', reason='Cancellation integration test')
    return next(iter(result[1].values()))


processes, logs, runs = [], [], []
try:
    for name in ['controller', 'worker']:
        logs.append((area / (name + '.log')).open('w'))
    processes.append(subprocess.Popen(['buildbot', 'start', '--nodaemon', str(master)],
                                      stdout=logs[0], stderr=logs[0]))
    wait_for('controller', lambda: get('builders'))
    request = urllib.request.Request(url + '/auth/login', headers={
        'Authorization': 'Basic ' + base64.b64encode(b'operator:test-only').decode()})
    with opener.open(request, timeout=10) as response:
        response.read()
    pending = queue()
    control('buildrequests/' + str(pending), 'cancel', reason='Cancel queued fixture')
    wait_for('queued cancellation', lambda: get('buildrequests/' + str(pending))['buildrequests'][0]['complete'])
    assert not get('builds')['builds']
    print('Queued cancellation: no worker command started.', flush=True)
    processes.append(subprocess.Popen(['twistd', '--nodaemon', '--logfile=-', '--python', str(area / 'worker.tac')],
        cwd=worker, env=environment, stdout=logs[1], stderr=logs[1]))
    wait_for('worker connection', lambda: any(w['connected_to'] for w in get('workers')['workers']))

    for mode in ['running-stop', 'killed-harness', 'launch-stop']:
        if mode == 'launch-stop':
            (area / 'hold-launch').touch()
        request_id = queue()
        build = wait_for('fixture build', lambda: next((b for b in get('builds')['builds']
                                                      if b['buildrequestid'] == request_id), None))
        workdir = worker / 'tvp-full/runs' / str(build['number'])
        launch = wait_for('exact run identity', lambda: json.loads((workdir / 'test-launch.json').read_text()))
        run = Path(launch['run'])
        runs.append(run)
        plan = json.loads((run / 'plan.json').read_text())
        kept = Path(next(j for j in plan['jobs'] if j['name'] == 'kept')['outputs'][0])
        blocked = next(j for j in plan['jobs'] if j['name'] == 'blocked')['drv']
        wait_for('completed output', lambda: kept.is_file())
        wait_for('active blocked build', lambda: any(a['drv'] == blocked for a in
                 json.loads((run / 'state.json').read_text())['active'].values()))
        if mode == 'killed-harness':
            pid = int((workdir / 'validation-owner.lock').read_text())
            assert Path(f'/proc/{pid}/cwd').resolve() == workdir
            os.kill(pid, signal.SIGKILL)
        else:
            control('builds/' + str(build['buildid']), 'stop', reason=mode)
        wait_for('stopped build', lambda: get('builds/' + str(build['buildid']))['builds'][0]['complete'])
        state = wait_for('detached runner cancellation', lambda: (
            value if (value := json.loads((run / 'state.json').read_text()))['phase'] == 'cancelled' else None), timeout=15)
        assert kept.read_text() == 'kept'
        assert state['jobs']['kept']['status'] == 'passed'
        assert state['jobs']['blocked']['status'] == 'cancelled'
        print(mode + ': detached runner stopped; completed output retained.', flush=True)
finally:
    for run in set(runs) | set((worker / 'tvp-full/runs').glob('*/validation/runs/*')):
        subprocess.run([str(run / 'runner/bin/tvp-test'), 'stop', '--run', str(run)],
                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
    for process in reversed(processes):
        process.terminate()
        process.wait(timeout=20)
    for log in logs:
        log.close()
print('Cancellation integration passed. Evidence:', area)

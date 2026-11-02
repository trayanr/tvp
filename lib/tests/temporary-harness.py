"""Exercise real owned temp dirs, including failure and cancellation cleanup."""
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time

runtime, bash = sys.argv[1:]


def cleaned(workspace, parent):
    paths = Path(workspace, 'temporary-paths').read_text().splitlines()
    assert paths and len(set(paths)) == len(paths), paths
    assert all(Path(p).parent == Path(parent) and not Path(p).exists() for p in paths), paths
    assert Path(parent, 'unowned').read_text() == 'keep'
    return paths


for name, expected in [('success', 0), ('exit7', 7), ('exit143', 143), ('signal143', 143)]:
    with tempfile.TemporaryDirectory() as work, tempfile.TemporaryDirectory() as tmp:
        Path(tmp, 'unowned').write_text('keep')
        p = subprocess.run([bash, runtime + '/' + name, work],
                           env=dict(os.environ, TMPDIR=tmp), capture_output=True, timeout=20)
        assert p.returncode == expected, (p.returncode, p.stderr)
        paths = cleaned(work, tmp)
        if name == 'success':
            assert Path(work, 'order').read_text() == 'first\nsecond\ninserted\nreplaced\n'
        print(name, expected, paths, flush=True)

for sig in [signal.SIGTERM, signal.SIGINT, signal.SIGHUP]:
    with tempfile.TemporaryDirectory() as work, tempfile.TemporaryDirectory() as tmp:
        Path(tmp, 'unowned').write_text('keep')
        p = subprocess.Popen([bash, runtime + '/cancel', work], env=dict(os.environ, TMPDIR=tmp),
                             stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True)
        try:
            deadline = time.monotonic() + 10
            while not Path(work, 'ready').exists():
                assert p.poll() is None and time.monotonic() < deadline
                time.sleep(.01)
            p.send_signal(sig)
            out, err = p.communicate(timeout=10)
            assert p.returncode == -sig, (p.returncode, err)
            print(sig.name, p.returncode, cleaned(work, tmp), flush=True)
        finally:
            if p.poll() is None:
                p.kill()
                p.communicate()

# Inject a failing deletion in the supervisor only. Child environment is clean.
# The test owns/removes leftovers after checking both status and diagnostic.
for name, expected in [('handled', 74), ('exit7', 7)]:
    with tempfile.TemporaryDirectory() as work, tempfile.TemporaryDirectory() as tmp:
        hook = Path(work, 'hook')
        hook.write_text('rm() { return 1; }\n')
        p = subprocess.run([bash, runtime + '/' + name, work],
                           env=dict(os.environ, TMPDIR=tmp, BASH_ENV=str(hook)),
                           capture_output=True, timeout=10)
        assert p.returncode == expected, (p.returncode, p.stderr)
        assert b'temporary cleanup failed' in p.stderr
        paths = Path(work, 'temporary-paths').read_text().splitlines()
        assert all(Path(path).is_dir() for path in paths)
        print('cleanup-error', name, expected, flush=True)
# Even a failed deletion cannot replace external cancellation's first signal.
with tempfile.TemporaryDirectory() as work, tempfile.TemporaryDirectory() as tmp:
    hook = Path(work, 'hook')
    hook.write_text('rm() { return 1; }\n')
    p = subprocess.Popen([bash, runtime + '/cancel', work],
                         env=dict(os.environ, TMPDIR=tmp, BASH_ENV=str(hook)),
                         stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True)
    try:
        deadline = time.monotonic() + 10
        while not Path(work, 'ready').exists():
            assert p.poll() is None and time.monotonic() < deadline
            time.sleep(.01)
        p.send_signal(signal.SIGTERM)
        out, err = p.communicate(timeout=10)
        assert p.returncode == -signal.SIGTERM, (p.returncode, err)
        assert b'temporary cleanup failed' in err
        print('cancellation-cleanup-error', p.returncode, flush=True)
    finally:
        if p.poll() is None:
            p.kill()
            p.communicate()

# Allocation fails before a child exists. Still report a terminal result and
# preserve cancellation observed while the supervisor waits for allocation.
for sig in [None, signal.SIGTERM, signal.SIGINT, signal.SIGHUP]:
    with tempfile.TemporaryDirectory() as work, tempfile.TemporaryDirectory() as tmp:
        hook = Path(work, 'hook')
        hook.write_text('''mktemp() {
    : > allocation-ready
    while [[ ! -e allocation-release ]]; do sleep 0.01; done
    return 17
}
''')
        p = subprocess.Popen([bash, runtime + '/handled', work],
                             env=dict(os.environ, TMPDIR=tmp, BASH_ENV=str(hook)),
                             stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True)
        try:
            deadline = time.monotonic() + 10
            while not Path(work, 'allocation-ready').exists():
                assert p.poll() is None and time.monotonic() < deadline
                time.sleep(.01)
            if sig is not None:
                p.send_signal(sig)
            Path(work, 'allocation-release').touch()
            out, err = p.communicate(timeout=10)
            expected = 17 if sig is None else -sig
            assert p.returncode == expected, (p.returncode, err)
            events = [json.loads(line[len('@tvp-step '):]) for line in
                      err.decode().splitlines() if line.startswith('@tvp-step ')]
            assert [event['event'] for event in events] == [
                'start', 'failure' if sig is None else 'cancellation'], events
            assert events[-1]['status'] == 17, events
            assert not Path(work, 'temporary-paths').exists()
            assert not list(Path(tmp).iterdir())
            print('allocation-error', sig, expected, flush=True)
        finally:
            if p.poll() is None:
                p.kill()
                p.communicate()

print('Temporary cleanup contracts passed.', flush=True)

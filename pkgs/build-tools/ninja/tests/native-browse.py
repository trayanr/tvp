"""Exercise the installed embedded browse service, including its Python runtime."""
import os
from pathlib import Path
import socket
import subprocess
import sys
import time
import urllib.request

Path('build.ninja').write_text('rule answer\n  command = printf 42 > $out\nbuild answer: answer\n')
with socket.socket() as sock:
    sock.bind(('127.0.0.1', 0))
    port = sock.getsockname()[1]
with open('browse.log', 'wb') as log:
    process = subprocess.Popen([sys.argv[1], '-t', 'browse', '--no-browser', '--port', str(port)],
                               env={'PATH': ''}, stdout=log, stderr=log)
    try:
        deadline = time.monotonic() + 15
        while True:
            if process.poll() is not None:
                raise AssertionError(Path('browse.log').read_text())
            try:
                with urllib.request.urlopen(f'http://127.0.0.1:{port}/?answer', timeout=1) as response:
                    assert response.status == 200
                    assert 'answer' in response.read().decode()
                break
            except OSError:
                if time.monotonic() >= deadline:
                    raise
                time.sleep(.05)
    finally:
        process.terminate()
        process.wait(timeout=5)
print('browse')

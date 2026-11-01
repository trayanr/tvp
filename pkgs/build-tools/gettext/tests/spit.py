"""Offline Ollama protocol fixture; no real model or translation service."""
import http.server
import json
import os
import subprocess
import sys
import threading

spit = sys.argv[1]
assert subprocess.run([spit, '--help'], capture_output=True).returncode == 0
assert b'1.0' in subprocess.check_output([spit, '--version'])
for args, expected in [([], b'missing --model'), (['--species=invalid'], b'unsupported')]:
    p = subprocess.run([spit, *args], input=b'', capture_output=True)
    assert p.returncode != 0, p
    # Diagnostics may be translated; these controls run with LC_ALL=C.
    if not args:
        assert expected in p.stderr, p.stderr

requests = []
class Handler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        assert self.path == '/api/generate'
        payload = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        requests.append(payload)
        if payload['model'] == 'error':
            self.send_error(503)
            return
        self.send_response(200)
        self.send_header('Content-Type', 'application/x-ndjson')
        self.end_headers()
        self.wfile.write(b'{"response":"Bon","done":false}\n{"response":"jour","done":true}\n')
    def log_message(self, *args):
        pass

server = http.server.HTTPServer(('127.0.0.1', 0), Handler)
thread = threading.Thread(target=server.serve_forever, daemon=True)
thread.start()
try:
    url = f'http://127.0.0.1:{server.server_port}'
    env = {**os.environ, 'NO_PROXY': '*', 'no_proxy': '*'}
    p = subprocess.run([spit, '--url', url, '--model=fixture', '--to=fr'], input='Hello'.encode(), capture_output=True, env=env, timeout=20)
    assert p.returncode == 0 and p.stdout == b'Bonjour', (p.returncode, p.stdout, p.stderr)
    assert requests[-1] == {'model':'fixture', 'prompt':'Translate into French:\nHello'}, requests
    p = subprocess.run([spit, '--url', url, '--model=fixture', '--prompt=literal'], input=b'input', capture_output=True, env=env, timeout=20)
    assert p.returncode == 0 and p.stdout == b'Bonjour', p
    assert requests[-1]['prompt'] == 'literal\ninput'
    p = subprocess.run([spit, '--url', url, '--model=fixture', '--postprocess=cat'], input=b'input', capture_output=True, env=env, timeout=20)
    assert p.returncode == 0 and p.stdout == b'Bonjour', (p.returncode, p.stdout, p.stderr)
    p = subprocess.run([spit, '--url', url, '--model=error'], input=b'input', capture_output=True, env=env, timeout=20)
    assert p.returncode != 0, p
finally:
    server.shutdown()
    thread.join()
    server.server_close()
print('ok')

"""Finite installed BUILD-profile proofs; raw upstream results are not conformance."""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shlex
import re
import shutil
import socket
import ssl
import subprocess
import sys
import tarfile
import time
import zipapp
import zipfile

out, evidence = map(Path, sys.argv[1:3])
c = json.loads(sys.argv[3])
evidence.mkdir(exist_ok=True)

def run(name, args, cwd=None, env=None, ok=True):
    p = subprocess.run(list(map(str, args)), cwd=cwd, env=env, text=True,
                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=180)
    (evidence / (name + '.log')).write_text(p.stdout)
    (evidence / (name + '.status')).write_text(str(p.returncode) + '\n')
    if ok and p.returncode: raise RuntimeError(name + ': ' + p.stdout)
    return p

assert sys.executable == c['python'] + '/bin/python3'
modules = {}
for name in ['_ssl', '_hashlib', 'zlib', '_bz2', '_lzma', 'socket', 'subprocess', 'sysconfig', 'multiprocessing']:
    m = __import__(name); modules[name] = m.__file__
    assert m.__file__.startswith(c['python'] + '/')
for name in c['disabled']:
    assert importlib.util.find_spec(name) is None, name
assert not importlib.util.find_spec('pip')
assert hashlib.sha256(b'abc').hexdigest() == 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'
assert hashlib.pbkdf2_hmac('sha256', b'password', b'salt', 1).hex() == '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b'
run('archives', [sys.executable, c['archives']], env={})
Path('app').mkdir(); Path('app/__main__.py').write_text('import ssl,lzma; print(42)\n')
zipapp.create_archive('app', 'compressed.pyz', interpreter=sys.executable, compressed=True)
with zipfile.ZipFile('compressed.pyz') as z:
    assert all(i.compress_type == zipfile.ZIP_DEFLATED for i in z.infolist())
assert run('zipapp-env-i', [str(Path('compressed.pyz').resolve())], env={}).stdout.strip() == '42'
Path('argv.py').write_text('import sys; print(repr(sys.argv[1:]))\n')
assert run('argv', [sys.executable, 'argv.py', 'space argument', '$literal', '']).stdout.strip() == "['space argument', '$literal', '']"
# The owned subprocess patch does not change libc os.system's /bin/sh contract.
assert subprocess.check_output('printf shell-ok', shell=True, env={}, text=True) == 'shell-ok'
assert c['shell'] in Path(__import__('subprocess').__file__).read_text()
(out / 'bin').mkdir(parents=True)
flags = shlex.split(run('python-config', [c['python'] + '/bin/python3-config', '--cflags', '--embed', '--ldflags'], env={}).stdout)
assert c['python'] + '/include/python3.12' in ' '.join(flags)
run('embed-compile', [os.environ['CC'], c['embed'], '-o', out / 'bin/embed', *flags])
assert run('embed-env-i', [out / 'bin/embed'], env={}).stdout.strip() == '42'
run('embed-loader', [out / 'bin/embed'], env={'LD_DEBUG':'libs'})
# A fresh extension also exercises retained headers, SOABI and sysconfig CC.
import sysconfig
Path('fresh.c').write_text('#include <Python.h>\nstatic PyObject *answer(PyObject*s,PyObject*a){return PyLong_FromLong(42);}\nstatic PyMethodDef methods[]={{"answer",answer,METH_NOARGS,0},{0}};\nstatic struct PyModuleDef def={PyModuleDef_HEAD_INIT,"fresh",0,-1,methods};\nPyMODINIT_FUNC PyInit_fresh(void){return PyModule_Create(&def);}\n')
ext = out / ('fresh' + sysconfig.get_config_var('EXT_SUFFIX'))
run('extension-compile', [*shlex.split(sysconfig.get_config_var('CC')), '-shared', '-fPIC', 'fresh.c', '-I' + sysconfig.get_path('include'), '-o', ext])
assert run('extension-import', [sys.executable, '-c', 'import sys;sys.path.insert(0,sys.argv[1]);import fresh;print(fresh.answer())', out], env={}).stdout.strip() == '42'
run('python-loader', [sys.executable, '-c', 'import ssl,hashlib,zlib,bz2,lzma; print(open("/proc/self/maps").read())'], env={})
# Declared local CA and OpenSSL server, with all subprocesses reaped.
tls = Path('tls'); tls.mkdir()
(tls / 'openssl.cnf').write_text('[req]\ndistinguished_name=dn\n[dn]\n')
(tls / 'server.ext').write_text('subjectAltName=DNS:localhost\nbasicConstraints=CA:FALSE\nkeyUsage=digitalSignature,keyEncipherment\nextendedKeyUsage=serverAuth\n')
for name in ['ca', 'other']:
    run('tls-' + name, [c['openssl'], 'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-config', 'openssl.cnf', '-keyout', name+'-key.pem', '-out', name+'.pem', '-days', '1', '-subj', '/CN='+name, '-addext', 'basicConstraints=critical,CA:TRUE'], cwd=tls)
run('tls-csr', [c['openssl'], 'req', '-new', '-newkey', 'rsa:2048', '-nodes', '-config','openssl.cnf', '-keyout','key.pem','-out','server.csr','-subj','/CN=localhost'],cwd=tls)
run('tls-cert', [c['openssl'], 'x509', '-req','-in','server.csr','-CA','ca.pem','-CAkey','ca-key.pem','-CAcreateserial','-out','cert.pem','-days','1','-extfile','server.ext'],cwd=tls)
with socket.socket() as s: s.bind(('127.0.0.1',0)); port=s.getsockname()[1]
results={}
with (evidence/'tls-server.log').open('w') as log:
    server = subprocess.Popen([c['openssl'],'s_server','-accept','127.0.0.1:'+str(port),'-cert','cert.pem','-key','key.pem','-www','-quiet'],cwd=tls,stdout=log,stderr=log)
    try:
        for _ in range(100):
            assert server.poll() is None
            try:
                with socket.create_connection(('127.0.0.1',port),timeout=.1): break
            except OSError: time.sleep(.05)
        else: raise RuntimeError('TLS server did not listen')
        for name, ca, hostname, success in [('trusted','ca','localhost',True),('untrusted','other','localhost',False),('hostname','ca','wrong.invalid',False)]:
            context=ssl.create_default_context(cafile=str(tls/(ca+'.pem')))
            try:
                with socket.create_connection(('127.0.0.1',port),timeout=5) as s:
                    with context.wrap_socket(s,server_hostname=hostname) as conn:
                        conn.sendall(b'GET / HTTP/1.0\r\n\r\n'); data=conn.recv(16384)
                        assert b'HTTP/1.0 200 ok' in data
                        results[name]={'verified':True,'version':conn.version(),'cipher':conn.cipher()}
                assert success
            except ssl.SSLCertVerificationError as e:
                assert not success
                results[name]={'verified':False,'verify_code':e.verify_code,'reason':e.verify_message}
        assert results['untrusted']['verify_code']==20
        assert results['hostname']['verify_code']==62
    finally:
        server.terminate()
        try: status=server.wait(timeout=5)
        except subprocess.TimeoutExpired: server.kill();status=server.wait()
        (evidence/'tls-server.status').write_text(str(status)+'\n')
(evidence/'tls.json').write_text(json.dumps(results,indent=2))
# Source-only test harness/data. Installed modules remain first in the search path.
with tarfile.open(c['source']) as t:
    t.extractall('upstream', filter='data')
lib = Path('upstream/Python-3.12.5/Lib').resolve()
# Select families whose harness does not require disabled _testcapi extensions.
Path('regress.py').write_text('''import sys,unittest,json
sys.path.append(sys.argv[1])
names=sys.argv[2:]
suite=unittest.TestLoader().loadTestsFromNames(names)
r=unittest.TextTestRunner(verbosity=2).run(suite)
print('TVP_RESULT='+json.dumps(dict(tests=r.testsRun,failures=len(r.failures),errors=len(r.errors),skips=len(r.skipped))))
raise SystemExit(not r.wasSuccessful())
''')
regress={}
for family in ['test_zlib','test_bz2','test_lzma','test_zipfile','test_gzip','test_tarfile','test_ssl','test_subprocess']:
    p=run('upstream-'+family,[sys.executable,'regress.py',lib,'test.'+family],ok=False)
    regress[family]={'status':p.returncode,'raw':'upstream-'+family+'.log'}
    for line in p.stdout.splitlines():
        if line.startswith('TVP_RESULT='): regress[family].update(json.loads(line.split('=',1)[1]))
(evidence/'summary.json').write_text(json.dumps(dict(modules=modules,disabled=c['disabled'],openssl=ssl.OPENSSL_VERSION,tls=results,regressions=regress,sysconfig={k:sysconfig.get_config_var(k) for k in ['CC','CFLAGS','LDFLAGS','CONFIG_ARGS','SOABI','Py_ENABLE_SHARED','LIBRARY']},limits='Bounded source harness with installed stdlib; disabled test extensions remain absent. os.system remains outside shell contract.'),indent=2))
# Keep measured unsupported families visible; require meaningful successful cases.
assert sum(v.get('tests',0) for v in regress.values() if v['status']==0)>100

# Keep raw environmental failures; fail on every other unexpected regression.
for family in ['test_zlib','test_bz2','test_lzma','test_zipfile','test_gzip','test_ssl']:
    assert regress[family]['status']==0, regress[family]
allowed={'test_tarfile': {'test_modes'}, 'test_subprocess': {'test_user','test_group'}}
for family,names in allowed.items():
    raw=(evidence/('upstream-'+family+'.log')).read_text()
    measured=set(re.findall(r'^(?:FAIL|ERROR): (\w+)',raw,re.M))
    assert measured <= names, (family,measured)
(evidence/'sandbox-limits.json').write_text(json.dumps(dict(
    uidMap=Path('/proc/self/uid_map').read_text(),gidMap=Path('/proc/self/gid_map').read_text(),
    uid=os.getuid(),gid=os.getgid(),
    limits={k:sorted(v) for k,v in allowed.items()},
    qualification='Raw nonzeros retained: archive special-mode expectation and subprocess unmapped uid/gid transitions. No full family PASS claim.'),indent=2))

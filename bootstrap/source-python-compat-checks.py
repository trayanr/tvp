"""Independently validate the selected provider after measured OpenSSL4 failures."""
import json
import os
from pathlib import Path
import socket
import ssl
import subprocess
import sys
import tarfile
import warnings

out,evidence=map(Path,sys.argv[1:3]);c=json.loads(sys.argv[3])

def run(name,args,env=None,ok=True):
    p=subprocess.run(args,text=True,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=120)
    (evidence/(name+'.log')).write_text(p.stdout)
    (evidence/(name+'.status')).write_text(str(p.returncode)+'\n')
    if ok and p.returncode: raise RuntimeError(p.stdout)
    return p

Path('openssl.cnf').write_text('[req]\ndistinguished_name=dn\n[dn]\n')
run('certificate',[c['openssl'],'req','-x509','-newkey','rsa:2048','-nodes','-config','openssl.cnf','-keyout','key.pem','-out','cert.pem','-days','1','-subj','/CN=localhost','-addext','subjectAltName=DNS:localhost,IP:127.0.0.1,IP:::1','-addext','authorityInfoAccess=OCSP;URI:http://ocsp.invalid/,caIssuers;URI:http://ca.invalid/cert','-addext','crlDistributionPoints=URI:http://crl.invalid/list'])
cert=ssl._ssl._test_decode_cert('cert.pem')
assert ('IP Address','127.0.0.1') in cert['subjectAltName']
assert any(n=='IP Address' and ':' in v for n,v in cert['subjectAltName'])
assert cert['OCSP']==('http://ocsp.invalid/',)
assert cert['caIssuers']==('http://ca.invalid/cert',)
assert cert['crlDistributionPoints']==('http://crl.invalid/list',)
with warnings.catch_warnings():
    warnings.simplefilter('ignore',DeprecationWarning)
    protocols={}
    for name in ['TLSv1','TLSv1_1','TLSv1_2']:
        ctx=ssl.SSLContext(getattr(ssl,'PROTOCOL_'+name))
        assert ctx.protocol==getattr(ssl,'PROTOCOL_'+name)
        protocols[name]=int(ctx.protocol)
    # Real fixed-method TLS1.2 handshake and certificate verification, in process.
    server=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER);server.load_cert_chain('cert.pem','key.pem')
    client=ssl.SSLContext(ssl.PROTOCOL_TLSv1_2);client.verify_mode=ssl.CERT_REQUIRED;client.check_hostname=True;client.load_verify_locations('cert.pem')
    a,b=socket.socketpair()
    import threading
    errors=[]
    def serve():
        try:
            with server.wrap_socket(a,server_side=True) as conn:
                assert conn.recv(2)==b'42';conn.sendall(b'ok')
        except BaseException as e: errors.append(repr(e))
    thread=threading.Thread(target=serve);thread.start()
    with client.wrap_socket(b,server_hostname='localhost') as conn:
        assert conn.version()=='TLSv1.2';conn.sendall(b'42');assert conn.recv(2)==b'ok'
    thread.join(timeout=5);assert not thread.is_alive() and not errors
(evidence/'selected-provider.json').write_text(json.dumps(dict(certificate=cert,fixedProtocols=protocols,handshake='TLSv1.2 verified'),indent=2))
with tarfile.open(c['source']) as t: t.extractall('upstream',filter='data')
lib=Path('upstream/Python-3.12.5/Lib').resolve()
# Children need the pinned test harness, not a source stdlib override.
harness=Path('test-only');harness.mkdir();(harness/'test').symlink_to(lib/'test',target_is_directory=True)
env=dict(os.environ,PYTHONPATH=str(harness.resolve()))
selectors=['test.test_ssl.SimpleBackgroundTests.test_connect','test.test_ssl.SimpleBackgroundTests.test_connect_capath','test.test_ssl.SimpleBackgroundTests.test_connect_with_context','test.test_ssl.SimpleBackgroundTests.test_get_server_certificate','test.test_ssl.SimpleBackgroundTests.test_get_server_certificate_sni','test.test_ssl.TestSSLDebug.test_msg_callback_deadlock_bpo43577']
Path('focused.py').write_text('''import unittest,json,sys,ssl,subprocess,tarfile
r=unittest.TextTestRunner(verbosity=2).run(unittest.TestLoader().loadTestsFromNames(sys.argv[1:]))
print('TVP_RESULT='+json.dumps(dict(tests=r.testsRun,failures=len(r.failures),errors=len(r.errors),skips=len(r.skipped),origins={m.__name__:m.__file__ for m in [ssl,subprocess,tarfile]})))
raise SystemExit(not r.wasSuccessful())
''')
p=run('upstream-child-harness',[sys.executable,'focused.py',*selectors],env=env,ok=False)
result=json.loads(next(l.split('=',1)[1] for l in p.stdout.splitlines() if l.startswith('TVP_RESULT=')))
assert result['tests']==6
assert all(x.startswith(c['python']+'/') for x in result['origins'].values())
(evidence/'focused-summary.json').write_text(json.dumps(result,indent=2))
print(p.stdout,flush=True)
assert p.returncode==0
(out/'result').write_text('Selected OpenSSL provider, certificate decoding and fixed TLS handshake verified\n')

"""Offline TLS positive and negative controls against the selected loaded provider."""
from pathlib import Path
import socket
import ssl
import subprocess
import sys
import threading
import warnings

provider = Path(sys.argv[1])
assert ssl.OPENSSL_VERSION.startswith('OpenSSL 3.6.3 '), ssl.OPENSSL_VERSION
# Validate loaded DSOs, not only the version string or declared dependency.
maps = Path('/proc/self/maps').read_text()
for library in ('libssl.so.3', 'libcrypto.so.3'):
    paths = {line.split()[-1] for line in maps.splitlines() if library in line}
    assert paths == {str(provider / 'lib' / library)}, paths
Path('openssl.cnf').write_text('[req]\ndistinguished_name=dn\n[dn]\n')
result = subprocess.run([str(provider/'bin/openssl'), 'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-config', 'openssl.cnf', '-keyout', 'key.pem', '-out', 'cert.pem', '-days', '1', '-subj', '/CN=localhost', '-addext', 'subjectAltName=DNS:localhost,IP:127.0.0.1,IP:::1', '-addext', 'authorityInfoAccess=OCSP;URI:http://ocsp.invalid/,caIssuers;URI:http://ca.invalid/cert', '-addext', 'crlDistributionPoints=URI:http://crl.invalid/list'], capture_output=True)
assert result.returncode == 0, result.stderr
cert = ssl._ssl._test_decode_cert('cert.pem')
assert ('IP Address', '127.0.0.1') in cert['subjectAltName']
assert any(k == 'IP Address' and ':' in v for k, v in cert['subjectAltName'])
assert cert['OCSP'] == ('http://ocsp.invalid/',)
assert cert['caIssuers'] == ('http://ca.invalid/cert',)
assert cert['crlDistributionPoints'] == ('http://crl.invalid/list',)
with warnings.catch_warnings():
    warnings.simplefilter('ignore', DeprecationWarning)
    for name in ('TLSv1', 'TLSv1_1', 'TLSv1_2'):
        context = ssl.SSLContext(getattr(ssl, 'PROTOCOL_'+name))
        assert context.protocol == getattr(ssl, 'PROTOCOL_'+name)

def handshake(trusted, hostname):
    server = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    server.load_cert_chain('cert.pem', 'key.pem')
    with warnings.catch_warnings():
        warnings.simplefilter('ignore', DeprecationWarning)
        client = ssl.SSLContext(ssl.PROTOCOL_TLSv1_2)
    client.verify_mode = ssl.CERT_REQUIRED
    client.check_hostname = True
    assert client.verify_mode == ssl.CERT_REQUIRED and client.check_hostname
    if trusted:
        client.load_verify_locations('cert.pem')
    a, b = socket.socketpair()
    a.settimeout(5); b.settimeout(5)
    errors = []
    def serve():
        try:
            with server.wrap_socket(a, server_side=True) as conn:
                assert conn.recv(2) == b'42'
                conn.sendall(b'ok')
        except BaseException as error:
            errors.append(error)
    thread = threading.Thread(target=serve)
    thread.start()
    failure = None
    try:
        with client.wrap_socket(b, server_hostname=hostname) as conn:
            assert conn.version() == 'TLSv1.2'
            conn.sendall(b'42')
            assert conn.recv(2) == b'ok'
    except ssl.SSLCertVerificationError as error:
        failure = error
    finally:
        thread.join(timeout=6)
        assert not thread.is_alive()
    if trusted and hostname == 'localhost':
        assert failure is None and not errors, (failure, errors)
    else:
        assert failure is not None and errors
        assert failure.verify_code == (62 if trusted else 18), failure
handshake(True, 'localhost')
handshake(False, 'localhost')
handshake(True, 'wrong.invalid')
print('TLS verified: OpenSSL 3.6.3; trusted/untrusted/wrong-host; fixed TLS1.2; decode')

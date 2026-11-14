"""Preserve strict and suppressed EOF handling after an abrupt TLS peer close."""
from pathlib import Path
import socket
import ssl
import subprocess
import sys
import threading

provider = Path(sys.argv[1])
Path("openssl.cnf").write_text("[req]\ndistinguished_name=dn\n[dn]\n")
generated = subprocess.run(
    [str(provider / "bin/openssl"), "req", "-x509", "-newkey", "rsa:2048",
     "-nodes", "-config", "openssl.cnf", "-keyout", "key.pem", "-out", "cert.pem", "-days", "1",
     "-subj", "/CN=localhost", "-addext", "subjectAltName=DNS:localhost"],
    capture_output=True, timeout=30,
)
assert generated.returncode == 0, generated.stderr


def abrupt_close(protocol, suppress):
    server = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    server.load_cert_chain("cert.pem", "key.pem")
    # No unread session tickets: ensure the client closes after both handshakes.
    server.num_tickets = 0
    client = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
    client.load_verify_locations("cert.pem")
    server.minimum_version = server.maximum_version = protocol
    client.minimum_version = client.maximum_version = protocol
    a, b = socket.socketpair()
    a.settimeout(3)
    b.settimeout(3)
    ready, closed = threading.Event(), threading.Event()
    result, errors = [], []

    def serve():
        try:
            with server.wrap_socket(
                a, server_side=True, suppress_ragged_eofs=suppress
            ) as conn:
                assert conn.version() == protocol.name.replace("_", ".")
                ready.set()
                assert closed.wait(5), "client did not close"
                try:
                    data = conn.read()
                except ssl.SSLEOFError:
                    assert not suppress, "suppressed EOF still raised"
                    result.append("strict")
                else:
                    assert suppress and data == b"", (suppress, data)
                    result.append("suppressed")
        except BaseException as error:
            errors.append(error)
        finally:
            ready.set()
            a.close()

    thread = threading.Thread(target=serve)
    thread.start()
    try:
        with client.wrap_socket(b, server_hostname="localhost") as conn:
            assert conn.version() == protocol.name.replace("_", ".")
            assert ready.wait(5), "server did not complete handshake"
    finally:
        closed.set()
        b.close()
        thread.join(6)
        assert not thread.is_alive(), "server thread remains alive"
    assert not errors, errors
    assert result == ["suppressed" if suppress else "strict"], result


for protocol in (ssl.TLSVersion.TLSv1_2, ssl.TLSVersion.TLSv1_3):
    for suppress in (False, True):
        abrupt_close(protocol, suppress)
print("TLS EOF: strict/suppressed for TLS1.2/TLS1.3")

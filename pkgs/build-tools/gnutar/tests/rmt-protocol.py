"""Exercise installed rmt's local pipe protocol without a remote service."""
from pathlib import Path
import subprocess
import sys
p = subprocess.Popen([sys.argv[1]], stdin=subprocess.PIPE, stdout=subprocess.PIPE)
def command(request, expected):
    p.stdin.write(request); p.stdin.flush()
    actual = p.stdout.readline()
    assert actual == expected, (request, actual, expected)
# A failed open produces a protocol error plus its explanatory line.
p.stdin.write(b'O/no/such/tvp-rmt-file\n0\n'); p.stdin.flush()
assert p.stdout.readline().startswith(b'E')
assert p.stdout.readline().strip()
path = str(Path.cwd()/'remote-file').encode()
command(b'O'+path+b'\n66\n', b'A0\n')  # O_RDWR | O_CREAT
command(b'W7\npayload', b'A7\n')
command(b'L0\n0\n', b'A0\n')
command(b'R7\n', b'A7\n')
assert p.stdout.read(7) == b'payload'
command(b'C\n', b'A0\n')
p.stdin.close()
assert p.wait(timeout=10) == 0
assert Path('remote-file').read_bytes() == b'payload'
print('rmt-protocol-ok')

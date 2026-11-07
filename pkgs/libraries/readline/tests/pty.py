"""Bounded terminal probe and real line-edit/debugger fixtures; probe independently."""
import errno
import fcntl
import os
from pathlib import Path
import select
import struct
import subprocess
import sys
import termios
import time

if sys.argv[1] == '--probe':
    try:
        master, slave = os.openpty()
        os.close(master)
        os.close(slave)
    except OSError as e:
        if e.errno in [errno.ENOENT, errno.ENODEV, errno.ENXIO, errno.EPERM, errno.EACCES]:
            print(f'PTY unavailable: {e}', file=sys.stderr)
            sys.exit(77)
        raise
    sys.exit(0)

mode, program = sys.argv[1:]
master, slave = os.openpty()  # Any failure after probe success is a failure.
fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack('HHHH', 24, 80, 0, 0))
args = [program]
if mode == '--gawk':
    Path('debug.awk').write_text('BEGIN { print "debugger-run-ok" }\n')
    args += ['-D', '-f', 'debug.awk']
p = subprocess.Popen(args, stdin=slave, stdout=slave, stderr=slave, start_new_session=True)
os.close(slave)
transcript = bytearray()
def until(marker):
    deadline = time.monotonic() + 15
    while marker not in transcript:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise AssertionError(('terminal timeout', marker, bytes(transcript)))
        if select.select([master], [], [], remaining)[0]:
            data = os.read(master, 8192)
            assert data, bytes(transcript)
            transcript.extend(data)
try:
    if mode == '--readline':
        until(b'first> ')
        os.write(master, b'abc\x01X\n')
        until(b'second> ')
        os.write(master, b'\x10\x05Y\n')
        until(b'readline-edit-history-ok')
    elif mode == '--gawk':
        until(b'gawk> ')
        os.write(master, b'liZZ\x7f\x7fst\n')
        until(b'BEGIN { print')
        os.write(master, b'run\n')
        until(b'debugger-run-ok\r\n')
        os.write(master, b'quit\n')
    else:
        raise AssertionError(mode)
    assert p.wait(timeout=15) == 0, bytes(transcript)
finally:
    if p.poll() is None:
        p.kill()
        p.wait()
    os.close(master)
    print(transcript.decode(errors='replace'), file=sys.stderr)
print('terminal-fixture-pass')

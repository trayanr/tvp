"""Drive an actual terminal; left-arrow editing distinguishes Readline from fgets."""
import os, pty, select, subprocess, sys, time
master, slave = pty.openpty()
env = dict(os.environ, TERM='xterm', HOME=os.environ['TMPDIR'])
p = subprocess.Popen([sys.argv[1], '-interactive', '-list', '-noheader', ':memory:'], stdin=slave, stdout=slave, stderr=slave, env=env)
os.close(slave)
transcript = b''
def until(needle):
    global transcript
    deadline = time.monotonic()+10
    while needle not in transcript:
        if time.monotonic() >= deadline: raise RuntimeError(repr(transcript))
        if select.select([master], [], [], 1)[0]: transcript += os.read(master,65536)
try:
    until(b'sqlite> ')
    # Left arrow places the cursor before the semicolon, so insert 2 => 42.
    os.write(master,b'select 4;\x1b[D2\n')
    until(b'\r42\r\n')
    os.write(master,b'.quit\n')
    assert p.wait(timeout=10)==0
    print('readline editing works')
finally:
    if p.poll() is None: p.kill(); p.wait()
    os.close(master)

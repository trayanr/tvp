"""Launch the unchanged upstream suite with the POSIX default SIGPIPE."""
import os
import signal
import sys
signal.signal(signal.SIGPIPE, signal.SIG_DFL)
os.execv(sys.argv[1], sys.argv[1:])

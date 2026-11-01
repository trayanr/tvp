import json
import os
import signal
import sys

if sys.argv[1] == "signal":
    print(os.getpid(), flush=True)
    signal.pause()
elif sys.argv[1] == "exit":
    sys.exit(int(sys.argv[2]))
else:
    print(json.dumps({"args": sys.argv[1:], "path": os.environ["PATH"],
                      "system": os.environ["TVP_TEST_SYSTEM"],
                      "value": os.environ["TVP_PROBE_VALUE"]}))

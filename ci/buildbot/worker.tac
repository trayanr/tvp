# Run as the separate, unprivileged tvp-worker account on the same PC.
import os
from pathlib import Path
from twisted.application import service
from buildbot_worker.bot import Worker

application = service.Application('tvp-worker')
instance = Worker(
    '127.0.0.1', 9989, 'tvp-linux',
    Path(os.environ['TVP_CI_WORKER_PASSWORD_FILE']).read_text().strip(),
    os.environ.get('TVP_CI_WORKER_DIRECTORY', '/var/lib/tvp-worker'),
    keepalive=600, umask=0o077,
)
instance.setServiceParent(application)

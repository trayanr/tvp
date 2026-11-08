"""Bounded upstream scheduler tests plus its real FIFO pool, no CPU affinity dependency."""
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path('source/misc').resolve()))
import jobserver_test as upstream

upstream.NINJA_PATH = sys.argv[1]
names = ['test_no_jobserver_client', 'test_jobserver_client_with_posix_pipe',
         'test_client_passes_MAKEFLAGS']
suite = unittest.TestSuite(upstream.JobserverTest(name) for name in names)
result = unittest.TextTestRunner(verbosity=2).run(suite)
assert result.testsRun == 3 and result.wasSuccessful() and not result.skipped
with upstream.BuildDir(upstream.generate_build_plan(8)) as build:
    build.ninja_run(['all'], prefix_args=[sys.executable, '-S',
                    str(Path('source/misc/jobserver_pool.py').resolve()), '--jobs=2'])
    assert upstream.compute_max_overlapped_spans(build.path, 8) == 2
print('scheduling')

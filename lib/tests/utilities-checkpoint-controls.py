"""Deferred tiny controls; run explicitly by the parent, not source-stage evidence."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile

spec = importlib.util.spec_from_file_location('checkpoint', sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
root = Path(tempfile.mkdtemp(prefix='nix-build-utilities-checkpoint-'))
try:
    original = root / 'original'
    original.mkdir()
    (original / 'source-date-epoch').write_text('315532800\n')
    source, build = original / 'source', original / 'build'
    source.mkdir(); build.mkdir()
    (source / 'input').write_text('source')
    (build / 'output').write_text('compiled')
    stamp = 1234567890000000000
    os.utime(source / 'input', ns=(stamp, stamp))
    checkpoint = root / 'checkpoint'
    module.save(str(original), str(checkpoint), [str(source), str(build)], str(source))
    shutil.rmtree(source); shutil.rmtree(build)
    current = root / 'current'; current.mkdir()
    module.restore(str(checkpoint), str(current))
    assert (source / 'input').read_text() == 'source'
    assert (build / 'output').read_text() == 'compiled'
    assert (source / 'input').stat().st_mtime_ns == stamp
    assert (current / 'tree-path').read_text().strip() == str(source)
    # An existing destination is rejected before any additional tree is written.
    try: module.restore(str(checkpoint), str(current))
    except ValueError: pass
    else: raise AssertionError('existing destination accepted')
    shutil.rmtree(source); shutil.rmtree(build)
    source.symlink_to(root / 'outside')
    try: module.restore(str(checkpoint), str(current))
    except ValueError: pass
    else: raise AssertionError('symlink destination accepted')
    source.unlink()
    # A symlinked parent is rejected before any target is created.
    shutil.rmtree(original)
    outside = root / 'outside'; outside.mkdir()
    original.symlink_to(outside, target_is_directory=True)
    try: module.restore(str(checkpoint), str(current))
    except ValueError: pass
    else: raise AssertionError('symlink parent accepted')
    assert list(outside.iterdir()) == []
    print('two-directory restore and destination/parent rejections')
finally:
    shutil.rmtree(root)

"""Tiny retained-state/classifier contracts. No SQLite or toolchain execution."""
import importlib.util
import json
import os
from pathlib import Path
import sys
import tempfile


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


state = load('state', sys.argv[1])
classifier = load('classifier', sys.argv[2])
manifest = Path(sys.argv[3])
restore = load('restore', sys.argv[4])
restore.namespace = state.namespace
with tempfile.TemporaryDirectory() as tmp:
    root = Path(tmp)
    for protocol in ('quick', 'veryquick'):
        source = root / protocol
        source.mkdir()
        (source / 'src').mkdir(); (source / 'test').mkdir()
        (source / '.libs').mkdir(); (source / '.deps').mkdir()
        for path in ('Makefile','Makefile.in','config.status','libtool','.tcl-env.sh','auto.def','sqlite3.c','parse.c','parse.h','config.h','sqlite_cfg.h','lemon','engine.o','.libs/libsqlite3.so','.deps/engine.Plo'):
            (source / path).write_text(str(source) + '\nprefix=/nix/store/production-prefix\n')
        (source / 'lemon').chmod(0o755)
        (source / '.libs/libsqlite3.so.0').symlink_to('libsqlite3.so')
        (source / 'test.db').write_text('temporary database')
        (source / 'config.log').write_text('obsolete log')
        (source / 'testfixture').write_text('test executable')
        os.utime(source / 'engine.o', ns=(120123456789,120123456789))
        epoch = root / 'epoch'; epoch.write_text('12345\n')
        out = root / (protocol + '-state')
        state.save(source, out, manifest, protocol, '/nix/store/production-prefix', epoch)
        layout = json.loads((out / 'layout.json').read_text())
        assert all(p not in layout['members'] for p in ('test.db','config.log','testfixture'))
        workspace = root / (protocol + '-private'); workspace.mkdir()
        restore.restore(out, workspace)
        private = Path((workspace / 'tree-path').read_text().strip())
        assert private == workspace / 'source'
        assert (private / 'engine.o').stat().st_mtime_ns == 120123456789
        assert (private / 'lemon').stat().st_mode & 0o100
        assert (private / '.libs/libsqlite3.so.0').readlink() == Path('libsqlite3.so')
        assert str(private) in (private / 'Makefile').read_text()
        assert 'prefix=/nix/store/production-prefix' in (private / 'Makefile').read_text()
        assert (private / 'engine.o').read_bytes() == (source / 'engine.o').read_bytes()
        (private / 'src' / 'private-marker').write_text('private')
        assert not (source / 'src' / 'private-marker').exists()
        # T's archive carries the private fixture, while A's archive excludes it.
        (private / 'testfixture').write_text('#!/bin/sh\n# libtool launcher '+str(private))
        (private / 'testfixture').chmod(0o755)
        state.save(private, root / (protocol + '-T'), manifest, protocol,
                   '/nix/store/production-prefix', epoch, fixture=True)
        relocated = root / (protocol + '-relocated'); relocated.mkdir()
        restore.restore(root / (protocol + '-T'), relocated)
        restored = Path((relocated / 'tree-path').read_text().strip())
        assert str(restored) in (restored / 'testfixture').read_text()
        assert str(restored) in (restored / '.tcl-env.sh').read_text()
        assert 'testfixture' in json.loads((root / (protocol + '-T') / 'layout.json').read_text())['members']
        (source / 'outside').symlink_to('/nix/store')
        try:
            state.save(source, root / 'bad', manifest, protocol, 'prefix', epoch)
        except ValueError:
            pass
        else:
            raise AssertionError('outside symlink accepted')
    raw = root / 'raw';raw.mkdir()
    (raw / 'exit').write_text('0\n'); (raw / 'output').write_text('0 errors out of 1 tests\n')
    assert classifier.classify(raw) == 'SQLite upstream raw result accepted'
    for exit_,output in [('1\n','0 errors out of 1 tests\n'),('0\n','0 errors out of'),('0\n',''),('0\n','0 errors out of 1 tests\n1 errors out of 2 tests\n'),('0\n','0 errors out of 1 tests in 1s\nupstream veryquick jobs=1 cases=1 errors=0 unfinished=0\n')]:
        (raw / 'exit').write_text(exit_); (raw / 'output').write_text(output)
        try:
            classifier.classify(raw)
        except ValueError:
            pass
        else:
            raise AssertionError('failed/missing/truncated/contradictory evidence accepted')
print('Retained state and strict raw evidence contracts passed')

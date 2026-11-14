"""Small source-confinement and frontend-classification regression fixtures."""
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile

guard, api, output = sys.argv[1:4]
historical = sys.argv[4] if len(sys.argv) == 5 else None
configure = """#!/bin/sh
PACKAGE_VERSION='1.12'
PACKAGE_STRING='automake 1.12'
 VERSION='1.12'
am__api_version='1.12'
APIVERSION=1.12
"""

def run(script, cwd, *arguments, success=True):
    result = subprocess.run([sys.executable, '-B', script, *map(str, arguments)],
                            cwd=cwd, capture_output=True, text=True)
    assert (result.returncode == 0) == success, (script, result.returncode, result.stderr)

def snapshot(root):
    return {str(p.relative_to(root)): p.read_bytes() for p in root.rglob('*')
            if p.is_file() and not p.is_symlink()}

with tempfile.TemporaryDirectory(dir=Path.cwd()) as temporary:
    top = Path(temporary)
    for link in ['symlink', 'hardlink']:
        for target in ['configure', 'nested/ltmain.sh']:
            root = top / (link + target.replace('/', '-'))
            root.mkdir()
            (root / 'configure').write_text(configure)
            outside = root.with_name(root.name + '-outside')
            outside.write_text(configure)
            path = root / target
            path.parent.mkdir(exist_ok=True)
            path.unlink(missing_ok=True)
            if link == 'symlink':
                path.symlink_to(os.path.relpath(outside, path.parent))
            else:
                os.link(outside, path)
            before = snapshot(root)
            run(guard, root, success=False)
            assert snapshot(root) == before and outside.read_text() == configure
            if target == 'configure':
                run(api, root, '1.88.4', '1.88', success=False)
                assert outside.read_text() == configure

    for invalid in ['missing-anchor', 'temporary-collision']:
        root = top / invalid
        root.mkdir()
        text = configure.replace("PACKAGE_VERSION='1.12'\n", '') if invalid == 'missing-anchor' else configure
        (root / 'configure').write_text(text)
        if invalid == 'temporary-collision':
            (root / 'configure.tvp-api-preparing').write_text('untouched')
        before = snapshot(root)
        run(api, root, '1.88.4', '1.88', success=False)
        assert snapshot(root) == before

    root = top / 'valid-source'
    root.mkdir()
    path = root / 'configure'
    path.write_text(configure)
    path.chmod(0o751)
    os.utime(path, ns=(1234567890000000000, 1234567890000000000))
    before = path.stat()
    run(guard, root)
    assert path.read_text() == configure
    run(api, root, '1.88.4', '1.88')
    assert "PACKAGE_VERSION='1.88.4'" in path.read_text()
    assert "APIVERSION='1.88'" in path.read_text()
    assert path.stat().st_mtime_ns == before.st_mtime_ns
    assert stat.S_IMODE(path.stat().st_mode) == 0o751
    assert not (root / 'configure.tvp-api-preparing').exists()

    classes = {name: 'perl' for name in ['autoheader', 'autom4te', 'autoreconf', 'autoscan', 'autoupdate', 'ifnames']}
    classes['autoconf'] = 'shell'
    config = {'family': 'autoconf', 'frontends': classes, 'shell': '/selected/bin/bash',
              'perl': '/selected/bin/perl', 'paths': ['/selected/bin'], 'replacements': []}
    cases = [
        ('python', 'bin/autoconf', '#!/usr/bin/python3\nprint("/artifact")\n'),
        ('path-substring', 'bin/autoconf', '#!/tmp/bash-looking/python3\nprint(42)\n'),
        ('wrong-class', 'bin/autoupdate', '#!/tmp/perl-looking/bash\necho 42\n'),
        ('unknown-share', 'share/late', '#!/usr/bin/python3\nprint(42)\n'),
        ('unknown-env', 'bin/autoupdate', '#!/usr/bin/env python3\nprint(42)\n'),
    ]
    for name, relative, data in cases:
        root = top / name
        (root / 'bin').mkdir(parents=True)
        (root / 'share').mkdir()
        (root / 'bin/autoconf').write_text('#!/bin/sh\necho /artifact\n')
        (root / relative).write_text(data)
        before = snapshot(root)
        run(output, root, root, '/artifact', json.dumps(config), success=False)
        assert snapshot(root) == before

    root = top / 'valid-output'
    (root / 'bin').mkdir(parents=True)
    (root / 'share').mkdir()
    (root / 'bin/autoconf').write_text('#! /bin/sh -e\necho /artifact\n')
    (root / 'bin/autoupdate').write_text('#!/tmp/bash-looking/perl -w\nprint 42;\n')
    (root / 'share/tap-driver.pl').write_text('#! /usr/bin/env perl\nprint 42;\n')
    run(output, root, root, '/artifact', json.dumps(config))
    assert (root / 'bin/autoconf').read_text().startswith('#!/selected/bin/bash -e\n')
    assert (root / 'bin/autoupdate').read_text().startswith('#!/selected/bin/perl -w\n')
    assert (root / 'share/tap-driver.pl').read_text().startswith('#!/selected/bin/perl\n')
    assert '/artifact' not in (root / 'bin/autoconf').read_text()
    if historical is not None:
        root = top / 'historical-output'
        (root / 'bin').mkdir(parents=True)
        (root / 'share').mkdir()
        (root / 'bin/autoconf').write_text('#! /bin/sh -e\necho /artifact\n')
        (root / 'bin/autoupdate').write_text('#!/bin/sh\necho /artifact\n')
        (root / 'bin/autoscan').write_text('#!/usr/bin/perl -w\nprint 42;\n')
        selected = dict(config, frontends={name: 'shipped' for name in classes})
        run(historical, root, root, '/artifact', json.dumps(selected))
        assert (root / 'bin/autoupdate').read_text().startswith('#!/selected/bin/bash\n')
        assert (root / 'bin/autoscan').read_text().startswith('#!/selected/bin/perl -w\n')
        (root / 'bin/autoscan').write_text('#!/usr/bin/python3\nprint(42)\n')
        before = snapshot(root)
        run(historical, root, root, '/artifact', json.dumps(selected), success=False)
        assert snapshot(root) == before
print('helper-contracts')

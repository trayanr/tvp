"""Finite pre-write guard controls; no Nix realization or Perl compilation."""
import json
import os
from pathlib import Path
import tempfile

from elf import inspect
from source import inventory, prepare


def main(config):
    tools = config['tools']
    contract = {'shell': config['shell'], 'diff': config['diff'],
                'buildPwd': config['pwd'], 'podHelper': 'ext/Pod-Html/t/lib/Testing.pm',
                'externalPwd': False, 'patches': []}
    results = []
    with tempfile.TemporaryDirectory(prefix='tvp-perl-guards-') as temporary:
        base = Path(temporary)

        def fixture(name):
            root = base / name
            root.mkdir()
            contents = {
                'Configure': b'#! /bin/sh\nCannot build with both -Duserelocatableinc and -Duseshrplib\n',
                'perl.c': b'#ifndef PERL_RELOCATABLE_INCPUSH\n',
                'hints/linux.sh': b'# sourced Linux hint\n',
                'ext/Pod-Html/t/lib/Testing.pm': b"my $diff = '/bin/diff';\n",
                'config_h.SH': b'headers\n', 'configpm': b'config generator\n',
                'installperl': b'installer\n', 'dist/PathTools/Cwd.pm': b'Cwd\n',
                'ext/Errno/Errno_pm.PL': b'Errno\n'}
            for n, data in contents.items():
                p = root / n
                p.parent.mkdir(parents=True, exist_ok=True)
                p.write_bytes(data)
            return root

        def reject(name, change, *, selected=None):
            root = fixture(name)
            change(root)
            before = (root / 'Configure').read_bytes()
            try:
                prepare(str(selected(root) if selected else root), contract)
            except (ValueError, UnicodeError, FileNotFoundError) as error:
                assert (root / 'Configure').read_bytes() == before
                results.append({'control': name, 'status': 'REJECTED_BEFORE_WRITE', 'error': repr(error)})
            else:
                raise AssertionError(('unexpected guard acceptance', name))

        reject('nul', lambda r: (r / contract['podHelper']).write_bytes(b"my $diff = '/bin/diff';\0"))
        reject('encoding', lambda r: (r / contract['podHelper']).write_bytes(b'\xff'))
        reject('frontend', lambda r: (r / 'Configure').write_bytes(b'#!/usr/bin/env -S sh -e\n'))
        reject('missing', lambda r: (r / 'installperl').unlink())
        reject('symlink-leaf', lambda r: ((r / 'installperl').unlink(), (r / 'installperl').symlink_to('configpm')))
        reject('outside-symlink', lambda r: (r / 'alias').symlink_to(base))
        reject('directory-symlink', lambda r: (r / 'alias').symlink_to('hints'))
        reject('special-node', lambda r: os.mkfifo(r / 'fifo'))
        reject('outside-hardlink', lambda r: os.link(r / 'Configure', base / 'external-alias'))
        reject('symlink-root', lambda r: (base / 'root-alias').symlink_to(r), selected=lambda r: base / 'root-alias')
        reject('symlink-parent', lambda r: (base / 'parent-alias').symlink_to(base),
               selected=lambda r: base / 'parent-alias' / r.name)
        reject('noncanonical-root', lambda r: None, selected=lambda r: str(r) + '/.')
        root = fixture('internal-hardlink')
        os.link(root / 'Configure', root / 'configure-alias')
        result = prepare(str(root), contract)
        assert (root / 'Configure').stat().st_ino == (root / 'configure-alias').stat().st_ino
        assert (root / 'Configure').read_bytes() == (root / 'configure-alias').read_bytes()
        results.append({'control': 'contained-hardlink', 'status': 'PASS_PRESERVED_INODE',
                        'groups': result['internalHardlinkGroups']})
        cache = Path(config['cache'])
        libperl = next(cache.glob('lib/*/*/CORE/libperl.so'))
        before = libperl.read_bytes()
        try:
            inspect(libperl, str(cache).encode(), '/nix/store/missing-perl-prototype-inspector')
        except FileNotFoundError:
            assert libperl.read_bytes() == before
            results.append({'control': 'missing-ELF-inspector', 'status': 'REJECTED_WITHOUT_WRITE'})
        else:
            raise AssertionError('missing inspector accepted')
    return results


if __name__ == '__main__':
    import sys
    print(json.dumps(main(json.loads(Path(sys.argv[1]).read_text())), indent=2))

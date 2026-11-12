"""Tiny SOURCE ONLY copy/finalizer fixtures and rendered shell syntax checks.

Use only explicitly passed cached inspectors; never realize or execute a target.
All disposable fixture files stay under the designated evidence directory.
"""
import importlib.util
import json
import os
from pathlib import Path
import shlex
import struct
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
    return m


def obj(value, section=b'.rodata', flags=2):
    names = b'\0.shstrtab\0' + section + b'\0'
    payload = b'\0' + value + b'\0'; off = 64 + len(names)
    table = (off + len(payload) + 7) // 8 * 8
    h = bytearray(64); h[:7] = b'\x7fELF\x02\x01\x01'
    struct.pack_into('<HHI', h, 16, 1, 62, 1)
    struct.pack_into('<Q', h, 40, table)
    struct.pack_into('<HHHHHH', h, 52, 64, 0, 0, 64, 3, 1)
    sections = bytes(64) + struct.pack('<IIQQQQIIQQ', 1, 3, 0, 0, 64, len(names), 0, 0, 1, 0)
    sections += struct.pack('<IIQQQQIIQQ', 11, 1, flags, 0, off, len(payload), 0, 0, 1, 0)
    return bytes(h) + names + payload + bytes(table - off - len(payload)) + sections


def reject(call):
    try:
        call()
    except (ValueError, FileNotFoundError, subprocess.CalledProcessError):
        return
    raise AssertionError('unsafe fixture accepted')


def main():
    evidence, evaluated, bash, readelf, coreutils = sys.argv[1:]
    data = json.loads(Path(evaluated).read_text())
    count = 0
    for row in data['rows'].values():
        for c in row['commands']:
            subprocess.run([bash, '-n', '-c', c['run']], check=True, capture_output=True)
            count += 1
    gawk = load('gawk_finalizer', ROOT / 'pkgs/build-tools/gawk/ordinary/finalize-3.py')
    elf = load('elf', ROOT / 'pkgs/libraries/libxml2/ordinary/elf.py')
    with tempfile.TemporaryDirectory(dir=evidence, prefix='tiny-') as tmp:
        tmp = Path(tmp); artifact = tmp / 'artifact'; out = tmp / 'finished'
        artifact.mkdir(); (artifact / 'bin').mkdir(); (artifact / 'share').mkdir()
        old = os.fsencode(artifact)
        slot = b'/bin/sh\0TVP_ORDINARY_SHELL_' + b'X' * 238
        (artifact / 'bin/gawk').write_bytes(obj(b'.:' + old + b'/share/awk\0' + old + b'/share/locale\0' + slot))
        (artifact / 'bin/igawk').write_text('#!/bin/sh\ngawk -f program\n')
        (artifact / 'bin/igawk').chmod(0o755)
        (artifact / 'share/metadata').write_bytes(old + b'/share/awk\n')
        (artifact / 'bin/awk').symlink_to('gawk')
        before = (artifact / 'bin/gawk').read_bytes()
        copy = next(c['run'] for c in data['rows']['gawk_3_0_6']['commands'] if c['name'] == 'output.copy-artifacts')
        env = {**os.environ, 'TVP_ARTIFACT_ROOT': str(artifact), 'out': str(out), 'PATH': coreutils + '/bin'}
        subprocess.run([bash, '-euc', copy], env=env, check=True, capture_output=True)
        subprocess.run([sys.executable, '-B', str(ROOT / 'pkgs/build-tools/gawk/ordinary/finalize-3.py'), str(out), str(artifact), str(ROOT / 'lib/installed-tree.py'), str(ROOT / 'pkgs/libraries/libxml2/ordinary/elf.py'), readelf, bash], check=True, capture_output=True)
        assert old not in (out / 'bin/gawk').read_bytes()
        assert slot not in (out / 'bin/gawk').read_bytes()
        assert os.fsencode(bash) + b'\0' in (out / 'bin/gawk').read_bytes()
        assert (out / 'bin/awk').read_bytes() == (out / 'bin/gawk').read_bytes()
        assert str(out / 'bin').encode() in (out / 'bin/igawk').read_bytes()
        assert (artifact / 'bin/gawk').read_bytes() == before
        new = os.fsencode(out)
        for section, flags in [(b'.data', 3), (b'.rodata', 3), (b'.text', 6)]:
            p = tmp / 'bad.o'; payload = obj(b'.:' + old + b'/share/awk', section, flags); p.write_bytes(payload)
            reject(lambda: gawk.compiled(payload, elf.inspect(p, old, readelf), old, new))
        p = tmp / 'unknown.o'; payload = obj(old + b'/unowned'); p.write_bytes(payload)
        reject(lambda: gawk.compiled(payload, elf.inspect(p, old, readelf), old, new))
        reject(lambda: gawk.bind_shell(before, [], os.fsencode(bash)))
        (tmp / 'io.c').write_text('execl("/bin/sh", "sh", "-c", cmd, NULL);\n')
        reserve = str(ROOT / 'pkgs/build-tools/gawk/ordinary/reserve-3.py')
        subprocess.run([sys.executable, '-B', reserve, '1'], cwd=tmp, check=True, capture_output=True)
        assert b'\\0TVP_ORDINARY_SHELL_' in (tmp / 'io.c').read_bytes()
        reject(lambda: subprocess.run([sys.executable, '-B', reserve, '1'], cwd=tmp, check=True, capture_output=True))
        subprocess.run([sys.executable, '-B', reserve, '1', bash], cwd=tmp, check=True, capture_output=True)
        assert b'"' + os.fsencode(bash) + b'"' in (tmp / 'io.c').read_bytes()
    print(json.dumps({'shellCommandsParsed': count, 'copyArtifactUnchanged': True, 'compiledPathSlots': True, 'finalShellBinding': True, 'unsafeNativeSlotsRejected': True, 'targetExecution': False}))


if __name__ == '__main__':
    main()

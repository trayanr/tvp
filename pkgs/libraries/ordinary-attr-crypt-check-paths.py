"""Audit native lookup paths without rewriting supported loader spelling.

ORIGIN paths can be checked against their ELF location. LIB/PLATFORM and empty
or relative entries depend on runtime state: their existence is not certified.
Interpreters and pathname DT_NEEDED entries retain the stricter absolute audit.
"""
import os
from pathlib import Path
import re
import struct
import sys

sys.path.insert(0, sys.argv[3])
from common import elf, files, invocation, tool

root, config = invocation()
builds = [os.environ[k] for k in ('NIX_BUILD_TOP', 'TMPDIR')]
if any(not p.startswith('/') or p == '/' for p in builds):
    raise ValueError('expected absolute build directories')
artifact = os.environ.get('TVP_ARTIFACT_ROOT')
forbidden = builds + ([artifact] if artifact else [])
token = re.compile(r'\$(?:\{(ORIGIN|LIB|PLATFORM)\}|(ORIGIN|LIB|PLATFORM)(?![A-Za-z0-9_]))')
if config['elfKinds'] not in (None, ['runtime']):
    raise ValueError('expected runtime ELF selection')

def forbidden_path(value, path):
    for bad in forbidden:
        if bad in value:
            raise ValueError(('forbidden lookup prefix', value, path))
    if value.startswith('/'):
        resolved = os.path.realpath(value)
        for bad in forbidden:
            bad = os.path.realpath(bad)
            if os.path.commonpath([resolved, bad]) in (resolved, bad):
                raise ValueError(('forbidden build/artifact lookup', value, path))

def audit(value, path, *, rpath=False):
    if any(c in value for c in ('\0', '\n', '\r')):
        raise ValueError(('invalid lookup path', value, path))
    forbidden_path(value, path)
    if not rpath:
        if not value.startswith('/') or '$' in value or not os.path.exists(value):
            raise ValueError(('invalid absolute runtime pathname', value, path))
        return
    # Validate token names before substituting ORIGIN for inspection only.
    if '$' in token.sub('', value):
        raise ValueError(('unsupported loader token', value, path))
    expanded = token.sub(lambda m: str(path.parent) if (m[1] or m[2]) == 'ORIGIN' else m[0], value)
    forbidden_path(expanded, path)
    if expanded.startswith('/') and '$' not in expanded and not os.path.isdir(expanded):
        raise ValueError(('nonexistent runtime lookup directory', value, path))

for path in files(root, config['paths']):
    if config['elfKinds'] == ['runtime']:
        header = path.read_bytes()[:64]
        if header.startswith(b'\x7fELF') and len(header) >= 18 and struct.unpack_from('<H', header, 16)[0] == 1:
            if len(header) != 64 or header[4:7] != b'\x02\x01\x01':
                raise ValueError(('invalid relocatable ELF', path))
            _, machine, version = struct.unpack_from('<HHI', header, 16)
            shoff = struct.unpack_from('<Q', header, 40)[0]
            ehsize = struct.unpack_from('<H', header, 52)[0]
            shsize, shnum = struct.unpack_from('<HH', header, 58)
            if (machine != 62 or version != 1 or ehsize != 64 or shsize != 64
                    or not shnum or shoff < 64 or shoff + shsize * shnum > path.stat().st_size):
                raise ValueError(('invalid relocatable section table', path))
            with path.open('rb') as stream:
                stream.seek(shoff)
                for _ in range(shnum):
                    section = struct.unpack('<IIQQQQIIQQ', stream.read(shsize))
                    if section[1] != 8 and section[4] + section[5] > path.stat().st_size:
                        raise ValueError(('truncated relocatable section', path))
            tool(config['readelf'], '--wide', '--file-header', '--section-headers', path)
            continue
    classification = elf(path, config['readelf'])
    if classification is None or not classification[0]:
        continue
    rpath = tool(config['patchelf'], '--print-rpath', path).removesuffix('\n')
    for value in rpath.split(':') if rpath else []:
        audit(value, path, rpath=True)
    if classification[1]:
        audit(tool(config['patchelf'], '--print-interpreter', path).removesuffix('\n'), path)
    for needed in tool(config['patchelf'], '--print-needed', path).splitlines():
        if '/' in needed:
            audit(needed, path)

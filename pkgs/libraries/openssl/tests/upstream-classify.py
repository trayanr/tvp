"""Strict native zero-exit oracle; no failure allowlist or output rewriting."""
import hashlib
import json
from pathlib import Path
import re
import sys


def accept(root):
    if root.is_symlink() or not root.is_dir():
        raise ValueError('missing raw capture')
    data = {}
    for name in ('output', 'exit', 'capture.json'):
        p = root / name
        if p.is_symlink() or not p.is_file() or p.stat().st_nlink != 1:
            raise ValueError('missing or aliased capture evidence')
        data[name] = p.read_bytes()
    code = data['exit']
    if not re.fullmatch(rb'(?:0|[1-9][0-9]{0,2})\n', code) or int(code) > 255:
        raise ValueError('malformed native status')
    receipt = json.loads(data['capture.json'])
    if (type(receipt) is not dict
            or any(type(receipt.get(n)) is not int for n in ('schema', 'status', 'bytes'))
            or type(receipt.get('sha256')) is not str):
        raise ValueError('malformed capture receipt')
    expected = {'schema': 1, 'status': int(code), 'bytes': len(data['output']),
                'sha256': hashlib.sha256(data['output']).hexdigest()}
    if receipt != expected or not data['output']:
        raise ValueError('incomplete or inconsistent capture')
    if int(code) != 0:
        raise ValueError('nonzero native upstream status')
    print('OpenSSL upstream raw result accepted')


if __name__ == '__main__':
    accept(Path(sys.argv[1]))

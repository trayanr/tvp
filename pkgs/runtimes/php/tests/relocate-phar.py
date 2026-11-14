"""Signed loader relocation preserves payloads and rejects invalid signatures."""
import hashlib
import importlib.util
from pathlib import Path
import sys

spec = importlib.util.spec_from_file_location('php_relocate', Path(sys.argv[1]))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
old, new = b'/prefix/a', b'/prefix/b'
loader = b'#!' + old + b'/bin/php\n<?php __HALT_COMPILER();'
payload = b' ?>\r\nunchanged manifest and archive contents'


def signed(body, kind, algorithm):
    return body + hashlib.new(algorithm, body).digest() + kind.to_bytes(4, 'little') + b'GBMB'


def rejects(data):
    try:
        module.relocate_phar(data, old, new)
    except ValueError:
        return
    raise AssertionError('accepted invalid or unsupported PHAR relocation')


for kind, algorithm in [(1, 'md5'), (2, 'sha1'), (3, 'sha256'), (4, 'sha512')]:
    original = signed(loader + payload, kind, algorithm)
    expected = signed(loader.replace(old, new) + payload, kind, algorithm)
    assert module.relocate_phar(original, old, new) == expected
    assert expected[-8:] == original[-8:]
rejects(signed(loader + payload, 2, 'sha1').replace(b'unchanged', b'corrupted'))
rejects(loader + payload + (16).to_bytes(4, 'little') + b'GBMB')
rejects(signed(loader + payload + old, 2, 'sha1'))
assert module.relocate_phar(loader, old, new) == loader.replace(old, new)
print('8 PHAR relocation cases passed')

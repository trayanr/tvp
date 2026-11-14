"""Dynamic ownership regressions using an existing Perl artifact; no build/run."""
import importlib.util
import json
from pathlib import Path
import stat
import struct
import subprocess
import sys
import tempfile


def main(config, helper):
    spec = importlib.util.spec_from_file_location('perl_finalize', helper)
    finalizer = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(finalizer)
    old = config['artifact']
    original = (Path(old)/'bin/perl').read_bytes()
    shoff = struct.unpack_from('<Q', original, 40)[0]
    shnum = struct.unpack_from('<H', original, 60)[0]
    sections = [struct.unpack_from('<IIQQQQIIQQ', original, shoff + 64*i)
                for i in range(shnum)]
    dynamic = next(s for s in sections if s[1] == 6)
    string_index = dynamic[6]
    strings = sections[string_index]
    entries = [(p, *struct.unpack_from('<qQ', original, p))
               for p in range(dynamic[4], dynamic[4] + dynamic[5], 16)]
    rpath = next(v for p, t, v in entries if t in (15, 29))
    needed = next(p for p, t, v in entries if t == 1)
    spare = next(p for p, t, v in entries if t in (21, 12))
    symbols = next(s for s in sections if s[1] == 11 and s[6] == string_index)
    versions = next(s for s in sections if s[1] == 0x6ffffffe and s[6] == string_index)
    auxiliary = struct.unpack_from('<I', original, versions[4] + 8)[0]

    def value(data, pos, replacement):
        struct.pack_into('<Q', data, pos + 8, replacement)

    def tag(data, pos, replacement, string):
        struct.pack_into('<qQ', data, pos, replacement, string)

    mutations = {
        'shared-needed': lambda b: value(b, needed, rpath),
        'suffix-needed': lambda b: value(b, needed, rpath + 1),
        'shared-soname': lambda b: tag(b, spare, 14, rpath),
        'shared-filter': lambda b: tag(b, spare, 0x7fffffff, rpath),
        'shared-symbol': lambda b: struct.pack_into('<I', b, symbols[4] + 24, rpath),
        'suffix-symbol': lambda b: struct.pack_into('<I', b, symbols[4] + 24, rpath + 1),
        'shared-version-file': lambda b: struct.pack_into('<I', b, versions[4] + 4, rpath),
        'shared-version-name': lambda b: struct.pack_into('<I', b, versions[4] + auxiliary + 8, rpath),
        'duplicate-rpath': lambda b: tag(b, spare, 29, rpath),
        'invalid-string-index': lambda b: value(b, needed, strings[5] + 1),
        'unknown-dynamic-tag': lambda b: tag(b, spare, 0x60000000, rpath),
        'wrong-string-table-address': lambda b: value(b, next(p for p, t, v in entries if t == 5), strings[3] + 1),
        'wrong-symbol-table-address': lambda b: value(b, next(p for p, t, v in entries if t == 6), symbols[3] + 1),
        'wrong-version-table-address': lambda b: value(b, next(p for p, t, v in entries if t == 0x6ffffffe), versions[3] + 1),
    }
    results = []
    with tempfile.TemporaryDirectory(prefix='perl-dynamic-') as temporary:
        parent = Path(temporary)
        for i, (name, mutate) in enumerate([('exclusive-rpath', None), *mutations.items()]):
            root = parent/(str(i) + 'x'*(len(old) - len(str(parent)) - len(str(i)) - 1))
            assert len(str(root)) == len(old)
            root.mkdir()
            data = bytearray(original)
            if mutate:mutate(data)
            (root/'perl').write_bytes(data)
            (root/'perl').chmod(0o755)
            (root/'Config.pm').write_text("prefix='" + old + "'\n")

            def snapshot():
                return {p.name: (p.read_bytes(), stat.S_IMODE(p.stat().st_mode))
                        for p in root.iterdir()}

            before = snapshot()
            try:
                finalizer.finalize({'root': str(root), 'artifact': old, **config['tools']})
            except (ValueError, OSError, subprocess.CalledProcessError) as error:
                assert mutate is not None, repr(error)
                assert snapshot() == before, name
                if name.startswith(('shared-', 'suffix-')):
                    assert 'shares dynamic string bytes' in str(error), (name, repr(error))
                results.append({'case': name, 'status': 'REJECTED_BEFORE_WRITE', 'error': repr(error)})
            else:
                assert mutate is None, name
                assert old.encode() not in (root/'perl').read_bytes()
                results.append({'case': name, 'status': 'PASS'})
    return results


if __name__ == '__main__':
    print(json.dumps(main(json.loads(Path(sys.argv[1]).read_text()), Path(sys.argv[2])), indent=2))

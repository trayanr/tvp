"""Tiny synthetic archive controls. No compiler or Ruby execution."""
import importlib.util
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest

loader = importlib.util.spec_from_file_location('ruby_finalize', Path(__file__).parent / '../owned/finalize.py')
module = importlib.util.module_from_spec(loader)
loader.loader.exec_module(module)
AR, READELF = sys.argv[1:]
sys.argv[1:] = []
OLD = b'/nix/store/' + b'a'*32 + b'-ruby-2.0.0'
NEW = b'/nix/store/' + b'b'*32 + b'-ruby-2.0.0'


def obj(payload, flags=2, name=b'.rodata', kind=1):
    strings = b'\0.shstrtab\0' + name + b'\0'
    shoff = (64 + len(strings) + len(payload) + 7) // 8 * 8
    header = bytearray(64)
    header[:16] = b'\x7fELF\x02\x01\x01' + b'\0'*9
    struct.pack_into('<HHIQQQIHHHHHH', header, 16,
                     kind, 62, 1, 0, 0, shoff, 0, 64, 0, 0, 64, 3, 1)
    contents = bytes(header) + strings + payload
    contents += b'\0'*(shoff-len(contents))
    sections = [bytes(64), struct.pack('<IIQQQQIIQQ', 1, 3, 0, 0, 64, len(strings), 0, 0, 1, 0),
                struct.pack('<IIQQQQIIQQ', 11, 1, flags, 0, 64+len(strings), len(payload), 0, 0, 1, 0)]
    return contents + b''.join(sections)


class Finalization(unittest.TestCase):
    def test_equal_width_and_exact_paths(self):
        data = obj(OLD+b'/lib/ruby\0suffix\0'+OLD+b'\0')
        changed = module.object_paths(data, OLD, NEW)
        self.assertEqual(len(data), len(changed))
        self.assertNotIn(OLD, changed)
        self.assertEqual(changed.count(NEW), 2)
        self.assertEqual(data.replace(OLD, NEW), changed)

    def test_reject_unsupported_binary_owners_and_widths(self):
        for data in [obj(OLD+b'\0', flags=3), obj(OLD+b'\0', flags=6),
                     obj(OLD+b'\0', name=b'.data'), obj(b'prefix'+OLD+b'\0'),
                     obj(OLD+b'-other\0'), obj(OLD+b'/lib'), obj(OLD+b'\0', kind=3),
                     obj(OLD+b'\0', name=b'.gnu.lto_payload'), b'invalid']:
            with self.assertRaises(ValueError):
                module.object_paths(data, OLD, NEW)
        with self.assertRaises(ValueError):
            module.object_paths(obj(OLD+b'\0'), OLD, NEW+b'long')

    def test_gnu_archive_and_failed_member_leave_input_exact(self):
        with tempfile.TemporaryDirectory() as work:
            root = Path(work)
            source = root/'loadpath.o'
            source.write_bytes(obj(OLD+b'/lib/ruby/2.0.0\0'))
            archive = root/'libruby-static.a'
            subprocess.run([AR, 'rcsD', str(archive), str(source)], check=True)
            original = archive.read_bytes()
            staged = root/'staged'; staged.mkdir()
            result = module.relocate_archive(archive, OLD, NEW, AR, READELF, staged)
            self.assertEqual(archive.read_bytes(), original)
            self.assertNotIn(OLD, result.read_bytes())
            self.assertIn(NEW, result.read_bytes())
            member = subprocess.run([AR, 'p', str(result), 'loadpath.o'], check=True, capture_output=True).stdout
            self.assertEqual(member, source.read_bytes().replace(OLD, NEW))
            bad = root/'ruby.o'; bad.write_bytes(obj(OLD+b'\0', flags=3))
            subprocess.run([AR, 'rD', str(archive), str(bad)], check=True)
            original = archive.read_bytes()
            with self.assertRaises(ValueError):
                module.relocate_archive(archive, OLD, NEW, AR, READELF, staged)
            self.assertEqual(archive.read_bytes(), original)


if __name__ == '__main__':
    unittest.main()

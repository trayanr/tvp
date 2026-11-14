"""Bounded archive safety controls; no network."""
import importlib.util
import io
from pathlib import Path
import sys
import tarfile
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('gn_unpack', sys.argv.pop(1))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


class Extraction(unittest.TestCase):
    def test_flat_tree_and_modes(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            with tarfile.open(root/'a.gz', 'w:gz') as tar:
                for name, mode in [('LICENSE',0o644),('build/gen.py',0o755)]:
                    info = tarfile.TarInfo(name); info.size=2; info.mode=mode
                    tar.addfile(info, io.BytesIO(b'ok'))
            m.unpack(root/'a.gz',root/'out')
            self.assertEqual((root/'out/LICENSE').read_bytes(),b'ok')
            self.assertTrue((root/'out/build/gen.py').stat().st_mode & 0o111)

    def test_rejects_before_any_write(self):
        for name, kind, link in [('../sentinel',tarfile.REGTYPE,''),('/outside',tarfile.REGTYPE,''),
                                 ('link',tarfile.SYMTYPE,'../sentinel'),('link',tarfile.LNKTYPE,'../sentinel'),
                                 ('x',tarfile.FIFOTYPE,''),('x/../sentinel',tarfile.REGTYPE,'')]:
            with self.subTest(name=name, kind=kind), tempfile.TemporaryDirectory() as tmp:
                root=Path(tmp); (root/'sentinel').write_bytes(b'untouched')
                with tarfile.open(root/'a.gz','w:gz') as tar:
                    info=tarfile.TarInfo('valid'); info.size=2; tar.addfile(info,io.BytesIO(b'ok'))
                    info=tarfile.TarInfo(name); info.type=kind; info.linkname=link; tar.addfile(info)
                with self.assertRaises(ValueError): m.unpack(root/'a.gz',root/'out')
                self.assertFalse((root/'out').exists())
                self.assertEqual((root/'sentinel').read_bytes(),b'untouched')
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            with tarfile.open(root/'a.gz','w:gz') as tar:
                tar.addfile(tarfile.TarInfo('parent'))
                tar.addfile(tarfile.TarInfo('parent/file'))
            with self.assertRaises(ValueError): m.unpack(root/'a.gz',root/'out')
            self.assertFalse((root/'out').exists())


unittest.main()

"""Installed module roles require pinned content, with only explicit shell binding."""
import importlib
import io
from pathlib import Path
import tarfile
import tempfile
import unittest

observer = importlib.import_module('source-cmake-runtime-audit')


class ModuleBoundary(unittest.TestCase):
    def test_pinned_data_and_shells(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp) / 'installed'
            root.mkdir()
            files = {'Modules/FindFixture.cmake': b'message(STATUS "fixture")\n',
                     'Modules/SquishRunTestCase.sh': b'#!/bin/sh\necho fixture\n'}
            archive = Path(temp) / 'source.tar.gz'
            with tarfile.open(archive, 'w:gz') as source:
                for name, data in files.items():
                    info = tarfile.TarInfo('cmake-4.4.5/' + name)
                    info.size = len(data)
                    source.addfile(info, io.BytesIO(data))
                    path = root / name
                    path.parent.mkdir(exist_ok=True)
                    path.write_bytes(data.replace(b'#!/bin/sh', b'#!/nix/store/owned-bash/bin/bash'))
            self.assertEqual(len(observer.module_data(root, archive, '/nix/store/owned-bash/bin/bash')), 2)
            script = root / 'Modules/SquishRunTestCase.sh'
            original = script.read_bytes()
            script.write_bytes(files['Modules/SquishRunTestCase.sh'])
            with self.assertRaises(ValueError): observer.module_data(root, archive, '/nix/store/owned-bash/bin/bash')
            script.write_bytes(original)
            injected = root / 'Modules/injected'
            injected.write_bytes(b'\x7fELF')
            with self.assertRaises(ValueError): observer.module_data(root, archive, '/nix/store/owned-bash/bin/bash')
            injected.unlink()
            script.unlink()
            script.symlink_to(root / 'Modules/FindFixture.cmake')
            with self.assertRaises(ValueError): observer.module_data(root, archive, '/nix/store/owned-bash/bin/bash')


if __name__ == '__main__':
    unittest.main()

"""Pinned compressed zip members cannot smuggle foreign content or interpreters."""
import importlib
import io
from pathlib import Path
import tarfile
import tempfile
import subprocess
import stat
import sys
import shlex
import shutil
import unittest
import zipfile

observer=importlib.import_module('source-python-meson-runtime-audit')

class ZipBoundary(unittest.TestCase):
    def test_archive_data_and_interpreter(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);archive=root/'source.tar.gz';app=root/'meson.pyz'
            files={'meson.py':b'print(42)\n'}|{f'mesonbuild/module{i}.py':b'answer=42\n' for i in range(101)}
            with tarfile.open(archive,'w:gz') as t:
                for name,content in files.items():
                    info=tarfile.TarInfo('meson-1.12.1/'+name);info.size=len(content)
                    t.addfile(info,io.BytesIO(content))
            def write(*,foreign=False,interpreter='/nix/store/owned-python',compression=zipfile.ZIP_DEFLATED):
                app.write_bytes(('#!'+interpreter+'/bin/python3\n').encode())
                with zipfile.ZipFile(app,'a',compression=compression) as z:
                    for name,content in files.items():
                        z.writestr('__main__.py' if name=='meson.py' else name,content)
                    if foreign:z.writestr('injected',b'foreign')
            write();self.assertEqual(len(observer.zip_data(app,archive,'/nix/store/owned-python')),102)
            for args in [{'foreign':True},{'interpreter':'/usr'},{'compression':zipfile.ZIP_STORED}]:
                write(**args)
                with self.assertRaises(AssertionError):observer.zip_data(app,archive,'/nix/store/owned-python')

class InstalledModes(unittest.TestCase):
    def test_transform_and_failure_restore_read_only_mode(self):
        helper=Path(__file__).resolve().parent/'../pkgs/runtimes/python-build/owned/finalize.py'
        shell=shutil.which('bash')
        self.assertIsNotNone(shell)
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'read only';p.write_text('before');p.chmod(0o444)
            for command,expected in [('printf repaired > '+shlex.quote(str(p)),0),('exit 7',1)]:
                r=subprocess.run([sys.executable,str(helper),d,command,shell],capture_output=True)
                self.assertEqual(r.returncode,expected)
                self.assertEqual(stat.S_IMODE(p.stat().st_mode),0o444)
            self.assertEqual(p.read_text(),'repaired')

if __name__=='__main__':unittest.main()

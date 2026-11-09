"""Finite cache nonoverwrite and output-writer external-inode controls."""
import hashlib
import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

seed, render_file = map(Path, sys.argv[1:3]); del sys.argv[1:3]
spec = importlib.util.spec_from_file_location('gradle_render', render_file)
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)


class Helpers(unittest.TestCase):
    def seed(self, root):
        return subprocess.run([sys.executable,str(seed)],env=dict(os.environ,GRADLE_USER_HOME=str(root)),capture_output=True)

    def test_cache_nonoverwrite_ok_and_links(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp); home=root/'home'
            self.assertEqual(self.seed(home).returncode,0)
            caches=list(home.glob('wrapper/dists/*/*')); self.assertEqual(len(caches),1)
            cache=caches[0]; archive=next(cache.iterdir()); self.assertTrue(archive.is_symlink())
            target=os.readlink(archive)
            self.assertEqual(self.seed(home).returncode,0); self.assertEqual(os.readlink(archive),target)
            archive.unlink(); archive.write_bytes(b'existing'); self.assertEqual(self.seed(home).returncode,0)
            self.assertEqual(archive.read_bytes(),b'existing')
            archive.unlink(); marker=cache/(archive.name+'.ok'); marker.touch()
            self.assertEqual(self.seed(home).returncode,0); self.assertFalse(archive.exists()); marker.unlink()
            sentinel=root/'sentinel'; sentinel.write_bytes(b'outside')
            os.link(sentinel,archive); self.assertEqual(self.seed(home).returncode,0)
            self.assertEqual(sentinel.read_bytes(),b'outside'); archive.unlink()
            os.link(sentinel,marker); self.assertNotEqual(self.seed(home).returncode,0)
            self.assertEqual(sentinel.read_bytes(),b'outside')
            outside=root/'external'; outside.mkdir()
            other=root/'other'; other.mkdir(); (other/'wrapper').symlink_to(outside)
            self.assertNotEqual(self.seed(other).returncode,0); self.assertEqual(list(outside.iterdir()),[])

    def test_render_rejects_parent_links_and_existing_inodes(self):
        for kind in ('symlink','hardlink','directory','parent'):
            with self.subTest(kind=kind), tempfile.TemporaryDirectory() as tmp:
                root=Path(tmp); out=root/'out'; out.mkdir(); (out/'nix-support').mkdir()
                external=root/'external'; external.mkdir(); sentinel=external/'sentinel'; sentinel.write_bytes(b'outside')
                if kind=='parent': (out/'bin').symlink_to(external)
                else:
                    (out/'bin').mkdir(); dest=out/'bin/gradle'
                    if kind=='symlink': dest.symlink_to(sentinel)
                    elif kind=='hardlink': os.link(sentinel,dest)
                    else: dest.mkdir()
                with self.assertRaises(ValueError): m.render(str(out),'/shell','/jdk','/core','/python','9.3.1',str(seed))
                self.assertEqual(sentinel.read_bytes(),b'outside')
                self.assertEqual({p.name for p in external.iterdir()},{'sentinel'})


unittest.main()

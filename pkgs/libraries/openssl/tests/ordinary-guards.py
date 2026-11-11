"""Compile-free mutation guards; run with explicit cached tool paths as JSON."""
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
import sys


def load(path):
    s = importlib.util.spec_from_file_location('guard', path)
    m = importlib.util.module_from_spec(s); s.loader.exec_module(m); return m


config = json.loads(sys.argv.pop(1))
output, archive, elf, helper = [load(sys.argv.pop(1)) for _ in range(4)]
source = load(sys.argv.pop(1))
config.update(buildPerl=config['perl'], rehash=False, tools=[])



class Guards(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='openssl-guard-')
        self.old = '/nix/store/'+'a'*32+'-openssl-1.1.1'
        self.root = Path(self.tmp.name)/('f'*(len(self.old)-len(self.tmp.name)-1))
        self.root.mkdir()
        (self.root/'lib/pkgconfig').mkdir(parents=True)
        self.pc = self.root/'lib/pkgconfig/openssl.pc'
        self.pc.write_text('prefix='+self.old+'\n')
    def tearDown(self):
        self.tmp.cleanup()
    def run_final(self, config_=None):
        return output.finalize(helper,self.root,self.old,config_ or config,archive.relocate,elf.inspect)
    def rejects(self):
        original=self.pc.read_bytes()
        with self.assertRaises((ValueError, OSError)):
            self.run_final()
        self.assertEqual(original,self.pc.read_bytes())
    def test_text_and_internal_alias(self):
        (self.root/'lib/alias').symlink_to('pkgconfig/openssl.pc')
        self.run_final()
        self.assertIn(str(self.root),self.pc.read_text())
    def test_internal_hardlink(self):
        os.link(self.pc,self.root/'lib/pkgconfig/libssl.pc')
        self.run_final()
        self.assertEqual(self.pc.stat().st_ino,(self.root/'lib/pkgconfig/libssl.pc').stat().st_ino)
    def test_conflicting_hardlink_roles(self):
        os.link(self.pc,self.root/'lib/other'); self.rejects()
    def test_outside_hardlink(self):
        os.link(self.pc,Path(self.tmp.name)/'outside'); self.rejects()
    def test_outside_link(self):
        (self.root/'bad').symlink_to('/etc/passwd'); self.rejects()
    def test_link_cycle(self):
        (self.root/'bad').symlink_to('bad'); self.rejects()
    def test_dangling_planned_link(self):
        (self.root/'bad').symlink_to(self.old+'/missing'); self.rejects()
    def test_nul_metadata(self):
        self.pc.write_bytes(b'prefix=bad\0'+self.old.encode()); self.rejects()
    def test_bad_encoding(self):
        self.pc.write_bytes(b'prefix=\xff'+self.old.encode()); self.rejects()
    def test_special_node(self):
        os.mkfifo(self.root/'fifo'); self.rejects()
    def test_missing_inspector(self):
        c=dict(config,readelf='/nix/store/missing/bin/readelf')
        with self.assertRaises(ValueError): self.run_final(c)
        self.assertIn(self.old,self.pc.read_text())
    def test_nonpath_prefix(self):
        self.pc.write_text('x'+self.old); self.rejects()
    def test_archive_unknown_member(self):
        member=self.old.encode()
        header=b'name/           '+b'0           '+b'0     '+b'0     '+b'644     '+str(len(member)).encode().ljust(10)+b'`\n'
        data=b'!<arch>\n'+header+member+(b'\n' if len(member)%2 else b'')
        with self.assertRaises(ValueError):
            archive.relocate(data,self.old.encode(),str(self.root).encode(),config['readelf'],helper.replace_paths)

    def test_raw_link_components_fail_before_mutation(self):
        (self.root/'lib/plain').write_text('regular')
        for target in ['lib/plain/../pkgconfig/openssl.pc',
                       'lib/missing/../pkgconfig/openssl.pc',
                       'lib/plain/', 'lib/plain/.']:
            with self.subTest(target=target):
                alias = self.root/'bad'; alias.symlink_to(target)
                self.rejects(); alias.unlink()

    def test_semantic_metadata_alias_and_la_validation(self):
        la = self.root/'lib/libssl.la'; la.write_bytes(b'malformed\0metadata')
        self.rejects(); la.unlink()
        payload = self.root/'lib/payload'; payload.write_bytes(b'malformed\0metadata')
        (self.root/'lib/pkgconfig/libssl.pc').symlink_to('../payload')
        self.rejects()

    def test_source_roles_reject_aliases_and_corrupt_text_before_writes(self):
        for case in ['Configure', 'Makefile', 'Makefile.org', 'Makefile.in', 'doc.pod']:
            with self.subTest(case=case), tempfile.TemporaryDirectory() as d:
                root = Path(d)
                original = b':\n/bin/sh\n'
                (root/'safe.sh').write_bytes(b'#!/bin/sh\ntrue\n')
                before = (root/'safe.sh').read_bytes()
                (root/'payload').write_bytes(original + b'\0')
                (root/case).symlink_to('payload')
                with self.assertRaises(ValueError):
                    source.prepare(root, config['shell'], config['perl'])
                self.assertEqual((root/'safe.sh').read_bytes(), before)
                (root/case).unlink(); (root/case).write_bytes(original+b'\0')
                with self.assertRaises(ValueError):
                    source.prepare(root, config['shell'], config['perl'])
                self.assertEqual((root/'safe.sh').read_bytes(), before)


unittest.main()

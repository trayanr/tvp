"""Compile-free mutation guards; run with explicit cached tool paths as JSON."""
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import subprocess
import unittest
import sys


def load(path):
    s = importlib.util.spec_from_file_location('guard', path)
    m = importlib.util.module_from_spec(s); s.loader.exec_module(m); return m


config = json.loads(sys.argv.pop(1))
output, archive, elf, helper = [load(sys.argv.pop(1)) for _ in range(4)]
source = load(sys.argv.pop(1))
manuals = load(sys.argv.pop(1))
renderer = sys.argv.pop(1)
config.update(buildPerl=config['perl'], rehash=False, tools=[], manual={
    'perl': config['perl'], 'renderHelper': renderer, 'epoch': 'nix-support/source-date-epoch',
    'source': '/nix/store/missing-source', 'version': '0.9.7c', 'encoding': 'latin-1', 'sections': []})



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
        return output.finalize(helper,self.root,self.old,config_ or config,archive.relocate,elf.inspect,manuals.plan)
    def rejects(self):
        original=self.pc.read_bytes()
        with self.assertRaises((ValueError, OSError)):
            self.run_final()
        self.assertEqual(original,self.pc.read_bytes())
    def install_helper(self, name, body):
        path = self.root/name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(body)
        path.chmod(0o755)
        return path

    def fake_openssl(self):
        return self.install_helper('bin/openssl',
            b'#!'+config['shell'].encode()+b'\nprintf "selected:%s\\n" "$*"\n')

    def test_misc_perl_helpers_bind_runtime_commands(self):
        self.fake_openssl()
        for name in ['etc/ssl/misc/CA.pl', 'etc/ssl/misc/der_chop']:
            body = b"system('openssl', 'fixture') == 0 or die 'command failed';\n"
            if name.endswith('der_chop'):
                body = b"require 'getopts.pl';\n&Getopts('vd:') or die 'options';\n" + body
            path = self.install_helper(name, b'#!'+config['buildPerl'].encode()+b'\n'+body)
        self.run_final()
        for name in ['etc/ssl/misc/CA.pl', 'etc/ssl/misc/der_chop']:
            path = self.root/name
            result = subprocess.run([str(path)], env={'PATH': ''}, capture_output=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout, b'selected:fixture\n')

    def test_misc_shell_helper_binds_runtime_commands(self):
        self.fake_openssl()
        path = self.install_helper('etc/ssl/misc/CA.sh', b'#!/bin/sh\nopenssl fixture\n')
        self.run_final()
        result = subprocess.run([str(path)], env={'PATH': ''}, capture_output=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, b'selected:fixture\n')

    def test_misc_helpers_reject_unsupported_inputs_before_writes(self):
        for name, data in [
            ('CA.pl', b'#!/usr/bin/python3\nprint(1)\n'),
            ('der_chop', b'#!'+config['buildPerl'].encode()+b'\nprint "missing parser";\n'),
            ('unknown.pl', b'#!'+config['buildPerl'].encode()+b'\nprint "unsupported";\n'),
        ]:
            with self.subTest(name=name):
                path = self.install_helper('etc/ssl/misc/'+name, data)
                self.rejects()
                self.assertEqual(path.read_bytes(), data)
                path.unlink()

    def test_misc_helper_hardlink_roles_reject(self):
        first = self.install_helper('etc/ssl/misc/CA.pl', b'#!'+config['buildPerl'].encode()+b'\nexit 0;\n')
        os.link(first, self.root/'etc/ssl/misc/der_chop')
        self.rejects()

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
        for case in ['Configure', 'Makefile', 'Makefile.org', 'Makefile.in', 'Makefile.ssl', 'doc.pod']:
            with self.subTest(case=case), tempfile.TemporaryDirectory() as d:
                root = Path(d)
                original = b':\n/bin/sh\n'
                (root/'safe.sh').write_bytes(b'#!/bin/sh\ntrue\n')
                before = (root/'safe.sh').read_bytes()
                (root/'payload').write_bytes(original + b'\0')
                (root/case).symlink_to('payload')
                with self.assertRaises(ValueError):
                    source.prepare(root, config['shell'], config['perl'], config['coreutils'])
                self.assertEqual((root/'safe.sh').read_bytes(), before)
                (root/case).unlink(); (root/case).write_bytes(original+b'\0')
                with self.assertRaises(ValueError):
                    source.prepare(root, config['shell'], config['perl'], config['coreutils'])
                self.assertEqual((root/'safe.sh').read_bytes(), before)

    def test_source_makefile_ssl_target_preserves_alias(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d); (root/'crypto').mkdir()
            target=root/'crypto/Makefile.ssl'
            target.write_bytes(b'SHELL=/bin/sh\n#define CFLAGS "$(CC) $(CFLAG)"\n')
            target.chmod(0o640)
            alias=root/'crypto/Makefile'; alias.symlink_to('Makefile.ssl')
            before=alias.lstat()
            result=source.prepare(root,config['shell'],config['perl'],config['coreutils'])
            self.assertEqual(result['changed'],['crypto/Makefile.ssl'])
            self.assertEqual(target.read_bytes(),b'SHELL='+config['shell'].encode()+b'\n#define CFLAGS "$(notdir $(CC)) $(CFLAG)"\n')
            self.assertEqual(target.stat().st_mode & 0o777,0o640)
            self.assertEqual(os.readlink(alias),'Makefile.ssl')
            after=alias.lstat()
            self.assertEqual((after.st_ino,after.st_mode,after.st_mtime_ns,after.st_nlink),
                             (before.st_ino,before.st_mode,before.st_mtime_ns,before.st_nlink))

    def test_source_makefile_ssl_invalid_targets_reject_before_writes(self):
        for case in ['outside','chain','directory','dangling','hardlink','NUL','encoding','different-name','trailing-slash']:
            with self.subTest(case=case),tempfile.TemporaryDirectory() as d:
                root=Path(d)/'source';root.mkdir()
                safe=root/'safe.sh';safe.write_bytes(b'#!/bin/sh\ntrue\n')
                original=safe.read_bytes();metadata=safe.stat()
                target=root/'Makefile.ssl';target.write_bytes(b'SHELL=/bin/sh\n')
                alias=root/'Makefile';alias.symlink_to('Makefile.ssl')
                if case=='outside':
                    outside=Path(d)/'outside';outside.write_bytes(b'SHELL=/bin/sh\n')
                    target.unlink();target.symlink_to('../outside')
                elif case=='chain':
                    (root/'payload').write_bytes(target.read_bytes())
                    target.unlink();target.symlink_to('payload')
                elif case=='directory':target.unlink();target.mkdir()
                elif case=='dangling':target.unlink()
                elif case=='hardlink':os.link(target,Path(d)/'outside')
                elif case=='NUL':target.write_bytes(b'SHELL=/bin/sh\n\0')
                elif case=='encoding':target.write_bytes(b'SHELL=/bin/sh\n\xff')
                elif case=='different-name':
                    target.rename(root/'payload');alias.unlink();alias.symlink_to('payload')
                elif case=='trailing-slash':alias.unlink();alias.symlink_to('Makefile.ssl/')
                with self.assertRaises((ValueError,OSError)):
                    source.prepare(root,config['shell'],config['perl'],config['coreutils'])
                self.assertEqual(safe.read_bytes(),original)
                self.assertEqual(safe.stat().st_mtime_ns,metadata.st_mtime_ns)
    def test_source_coreutils_binding_and_command_boundaries(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            script = root/'testca'
            script.write_bytes(b'#!/bin/sh\n/bin/rm -f missing\n/usr/bin/cp a b\n'
                               b'/bin/mv a b\n/bin/cat a\n'
                               b'# /bin/rmdir /bin/rm.extra /opt/bin/rm prefix/bin/rm\n')
            source.prepare(root, config['shell'], config['perl'], config['coreutils'])
            self.assertEqual(script.read_text(), '#!'+config['shell']+'\n'
                             +config['coreutils']+'/bin/rm -f missing\n'
                             +config['coreutils']+'/bin/cp a b\n'
                             +config['coreutils']+'/bin/mv a b\n'
                             +config['coreutils']+'/bin/cat a\n'
                             +'# /bin/rmdir /bin/rm.extra /opt/bin/rm prefix/bin/rm\n')

    def test_source_missing_coreutils_rejects_before_writes(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            script = root/'testca'
            original = b'#!/bin/sh\n/bin/rm -f missing\n'
            script.write_bytes(original)
            with self.assertRaises(ValueError):
                source.prepare(root, config['shell'], config['perl'], '/nix/store/missing-coreutils')
            self.assertEqual(script.read_bytes(), original)

    def test_documentation_alias_relocates_validated_text(self):
        man = self.root/'etc/ssl/man/man7';man.mkdir(parents=True)
        page = man/'des_modes.7';page.write_text('manual '+self.old+'/etc/ssl\n')
        alias = man/'Modes of DES.7';alias.symlink_to('des_modes.7')
        self.run_final()
        self.assertEqual(os.readlink(alias), 'des_modes.7')
        self.assertEqual(alias.read_text(), 'manual '+str(self.root)+'/etc/ssl\n')

    def test_documentation_alias_rejects_wrong_roles_and_bad_text(self):
        for case in ['metadata', 'other-section', 'NUL', 'encoding', 'directory', 'dangling', 'self']:
            with self.subTest(case=case):
                man = self.root/'etc/ssl/man/man7';man.mkdir(parents=True, exist_ok=True)
                page = man/'des_modes.7';page.write_text('manual\n')
                alias = man/'Modes of DES.7'
                target = 'des_modes.7'
                if case=='metadata':target='../../../../lib/pkgconfig/openssl.pc'
                elif case=='other-section':
                    other=self.root/'etc/ssl/man/man3';other.mkdir()
                    (other/'des_modes.3').write_text('manual\n');target='../man3/des_modes.3'
                elif case=='NUL':page.write_bytes(b'manual\0')
                elif case=='encoding':page.write_bytes(b'manual\xff')
                elif case=='directory':page.unlink();page.mkdir()
                elif case=='dangling':page.unlink()
                elif case=='self':target='Modes of DES.7'
                alias.symlink_to(target)
                self.rejects()
                alias.unlink()
                if page.is_dir():page.rmdir()
                elif page.exists():page.unlink()


unittest.main()

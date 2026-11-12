"""Shared compile-free source-manual fixtures with the selected real Perl provider."""
import copy
import importlib.util
import io
import json
import os
from pathlib import Path
import sys
import tarfile
import tempfile
import unittest


def load(path):
    spec = importlib.util.spec_from_file_location('fixture', path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


config = json.loads(sys.argv.pop(1))
output, archive, elf, helper, manuals = [load(sys.argv.pop(1)) for _ in range(5)]
renderer = str(Path(sys.argv.pop(1)).absolute())
config.update(buildPerl=config['perl'], rehash=False, tools=[])
SECTIONS = [
    {'directory': 'doc/apps', 'section': '1', 'exceptions': {'config': '5'}},
    {'directory': 'doc/crypto', 'section': '3', 'exceptions': {'des_modes': '7'}},
    {'directory': 'doc/ssl', 'section': '3', 'exceptions': {}},
]
POD = b'=head1 NAME\n\n tiny - source payload\n\n=head1 DESCRIPTION\n\nGenuine source bytes.\n\n=cut\n'
HEADER = b'#define OPENSSL_VERSION_TEXT "OpenSSL 0.9.7c 30 Sep 2003"\n'


class Manuals(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='manual-fixture-')
        self.directory = Path(self.temp.name)
        self.old = '/nix/store/' + 'a'*32 + '-openssl-0.9.7c'
        self.root = self.directory/('r'*(len(self.old)-len(str(self.directory))-1))
        self.root.mkdir()
        (self.root/'lib/pkgconfig').mkdir(parents=True)
        (self.root/'lib/pkgconfig/openssl.pc').write_text('prefix='+self.old+'\n')
        (self.root/'nix-support').mkdir()
        (self.root/'nix-support/source-date-epoch').write_text('1064925495\n')
        man = self.root/'etc/ssl/man/man3'; man.mkdir(parents=True)
        self.page = man/'tiny.3'; self.page.symlink_to('tiny.3')
        (man/'alias.3').symlink_to('tiny.3')
        (man/'chain.3').symlink_to('alias.3')
        (man/'existing.3').write_text('Existing manual payload.\n')
        self.archive = self.directory/'source.tar.gz'
        self.members = [('crypto/opensslv.h', HEADER), ('doc/crypto/tiny.pod', POD)]
        self.write_archive()
        self.config = copy.deepcopy(config)
        self.config['manual'] = {'source': str(self.archive), 'version': '0.9.7c',
            'encoding': 'latin-1', 'perl': config['perl'], 'renderHelper': renderer,
            'sections': copy.deepcopy(SECTIONS), 'epoch': 'nix-support/source-date-epoch'}

    def tearDown(self):
        self.temp.cleanup()

    def write_archive(self, extra=()):
        with tarfile.open(self.archive, 'w:gz') as dest:
            for name, data in self.members + list(extra):
                member = tarfile.TarInfo('openssl-0.9.7c/'+name)
                if isinstance(data, tuple):
                    member.type, member.linkname = data
                    dest.addfile(member)
                else:
                    member.size = len(data)
                    dest.addfile(member, io.BytesIO(data))

    def snapshot(self):
        result = {}
        for path in self.root.rglob('*'):
            st = path.lstat()
            result[str(path.relative_to(self.root))] = (
                st.st_mode, st.st_ino, st.st_mtime_ns,
                os.readlink(path) if path.is_symlink() else path.read_bytes() if path.is_file() else None)
        return result

    def run_final(self):
        return output.finalize(helper, self.root, self.old, self.config,
                               archive.relocate, elf.inspect, manuals.plan)

    def rejects(self):
        before = self.snapshot()
        with self.assertRaises((ValueError, OSError, UnicodeError, tarfile.TarError)):
            self.run_final()
        self.assertEqual(before, self.snapshot(), 'rejection must precede every installed write')

    def test_restores_content_preserves_chains_and_payload(self):
        payload = self.root/'lib/payload'; payload.write_bytes(b'opaque\0non-document\xff')
        before = (self.page.parent/'existing.3').read_bytes()
        result = self.run_final()
        self.assertEqual(payload.read_bytes(), b'opaque\0non-document\xff')
        self.assertFalse(self.page.is_symlink())
        self.assertIn(b'Genuine source bytes.', self.page.read_bytes())
        self.assertIn(b'2003-09-30', self.page.read_bytes())
        self.assertNotIn(b'POD ERRORS', self.page.read_bytes())
        self.assertEqual(os.readlink(self.page.parent/'alias.3'), 'tiny.3')
        self.assertEqual(os.readlink(self.page.parent/'chain.3'), 'alias.3')
        self.assertEqual((self.page.parent/'existing.3').read_bytes(), before)
        self.assertEqual(sorted(result['restoredManuals']), ['etc/ssl/man/man3/tiny.3'])

    def test_renderer_is_deterministic_with_host_inputs_cleared(self):
        root, files, _, links = helper.tree(self.root)
        first = manuals.plan(root, files, links, self.config['manual'], output.role)
        saved = {k: os.environ.get(k) for k in ['PERL5OPT', 'PERL5LIB', 'TZ', 'SOURCE_DATE_EPOCH']}
        try:
            os.environ.update(PERL5OPT='-MNoSuchModule', PERL5LIB='/missing', TZ='Pacific/Honolulu', SOURCE_DATE_EPOCH='0')
            second = manuals.plan(root, files, links, self.config['manual'], output.role)
        finally:
            for k, v in saved.items():
                if v is None: os.environ.pop(k, None)
                else: os.environ[k] = v
        self.assertEqual(first, second)

    def test_all_source_roles_sections(self):
        for directory, stem, section in [('doc/apps', 'tool', '1'), ('doc/apps', 'config', '5'),
                                         ('doc/ssl', 'tls', '3'), ('doc/crypto', 'des_modes', '7')]:
            with self.subTest(directory=directory, stem=stem):
                self.write_archive([(directory+'/'+stem+'.pod', POD.replace(b'tiny', stem.encode()))])
                man = self.root/f'etc/ssl/man/man{section}'; man.mkdir(exist_ok=True)
                page = man/f'{stem}.{section}'; page.symlink_to(page.name)
                root, files, _, links = helper.tree(self.root)
                restored, _ = manuals.plan(root, files, links, self.config['manual'], output.role)
                self.assertIn(str(page.relative_to(root)), restored)
                page.unlink()

    def test_effective_source_encoding_and_renderer_edits_change_payload(self):
        root, files, _, links = helper.tree(self.root)
        def render():
            return manuals.plan(root, files, links, self.config['manual'], output.role)[0]
        first = render()
        self.members[1] = ('doc/crypto/tiny.pod', POD.replace(b'Genuine source bytes.', b'Changed source caf\xe9.'))
        self.write_archive()
        second = render()
        self.assertNotEqual(first, second)
        self.assertIn('Changed source café.'.encode(), next(iter(second.values())))
        selected = self.directory/'selected-renderer.pl'
        selected.write_text('print ".\\\" selected renderer\\n"; do '+json.dumps(renderer)+'; die $@ if $@;')
        self.config['manual']['renderHelper'] = str(selected)
        third = render()
        self.assertNotEqual(second, third)
        self.assertIn(b'selected renderer', next(iter(third.values())))

    def test_wrong_section_or_basename(self):
        for value in ['manualSections', 'basename']:
            with self.subTest(value=value):
                if value == 'manualSections':
                    self.config['manual']['sections'][1]['section'] = '7'
                else:
                    self.config['manual']['sections'] = copy.deepcopy(SECTIONS)
                    self.members[1] = ('doc/crypto/other.pod', POD)
                    self.write_archive()
                self.rejects()

    def test_source_binding_and_provider_failures(self):
        for key, bad in [('source', '/missing'), ('version', '0.9.8'), ('encoding', 'ascii'),
                         ('perl', '/nix/store/missing/bin/perl'), ('renderHelper', '/missing'),
                         ('epoch', '../source-date-epoch')]:
            with self.subTest(key=key):
                saved = self.config['manual'][key]
                self.config['manual'][key] = bad
                self.rejects()
                self.config['manual'][key] = saved

    def test_source_header_mismatch(self):
        self.members[0] = ('crypto/opensslv.h', HEADER.replace(b'0.9.7c', b'0.9.8'))
        self.write_archive(); self.rejects()

    def test_bad_encoding_nul_and_pod(self):
        for pod, encoding in [(POD+b'\0', 'latin-1'), (POD+b'\xff', 'utf-8'),
                              (b'not POD\n', 'utf-8'),
                              (b'=encoding unknown\n\n'+POD, 'latin-1'),
                              (b'=encoding utf8\n\n'+POD, 'latin-1'),
                              (b'=encoding latin-1\n\n=encoding latin-1\n\n'+POD, 'latin-1'),
                              (POD.replace(b'Genuine source bytes.', b'Z<bad>'), 'utf-8')]:
            with self.subTest(pod=pod):
                self.members[1] = ('doc/crypto/tiny.pod', pod)
                self.config['manual']['encoding'] = encoding
                self.write_archive(); self.rejects()

    def test_unsafe_missing_ambiguous_archive_roles(self):
        for case in ['missing', 'duplicate', 'ambiguous', 'symlink', 'hardlink', 'special', 'parent-link', 'escape']:
            with self.subTest(case=case):
                self.members = [('crypto/opensslv.h', HEADER), ('doc/crypto/tiny.pod', POD)]
                extra = []
                if case == 'missing': self.members.pop()
                elif case == 'duplicate': extra = [self.members[1]]
                elif case == 'ambiguous': extra = [('doc/ssl/tiny.pod', POD)]
                elif case == 'symlink': self.members[1] = ('doc/crypto/tiny.pod', (tarfile.SYMTYPE, '../payload'))
                elif case == 'hardlink': self.members[1] = ('doc/crypto/tiny.pod', (tarfile.LNKTYPE, 'payload'))
                elif case == 'special': self.members[1] = ('doc/crypto/tiny.pod', (tarfile.FIFOTYPE, ''))
                elif case == 'parent-link': extra = [('doc/crypto', (tarfile.SYMTYPE, '../elsewhere'))]
                elif case == 'escape': extra = [('../escape', b'bad')]
                self.write_archive(extra); self.rejects()

    def test_aliased_archive_renderer_and_epoch(self):
        for field in ['source', 'renderHelper']:
            original = self.config['manual'][field]
            alias = self.directory/field; alias.symlink_to(original)
            self.config['manual'][field] = str(alias)
            self.rejects(); self.config['manual'][field] = original
        epoch = self.root/'nix-support/source-date-epoch'
        epoch.unlink(); epoch.symlink_to(self.archive); self.rejects()

    def test_non_document_self_and_multihop_cycles(self):
        for case in ['ordinary', 'documentation']:
            with self.subTest(case=case):
                path = self.root/'other' if case == 'ordinary' else self.page.parent/'other.3'
                path.symlink_to(path.name); self.rejects(); path.unlink()
        a, b = self.page.parent/'a.3', self.page.parent/'b.3'
        a.symlink_to('b.3'); b.symlink_to('a.3'); self.rejects()

    def test_late_payload_error_after_render_does_not_write(self):
        (self.root/'lib/pkgconfig/bad.pc').write_bytes(b'late\0error')
        self.rejects()

    def test_multiple_restorations_finish_before_writes(self):
        other = self.page.parent/'z_missing.3'; other.symlink_to(other.name)
        self.rejects()
        self.write_archive([('doc/crypto/z_missing.pod', POD.replace(b'tiny', b'z_missing'))])
        result = self.run_final()
        self.assertEqual(len(result['restoredManuals']), 2)

    def test_pod_is_data_and_source_program_text_does_not_execute(self):
        marker = self.directory/'must-not-exist'
        program = ('BEGIN { open my $f, ">", "'+str(marker)+'"; print $f "executed"; }\n').encode()
        self.members[1] = ('doc/crypto/tiny.pod', program + POD)
        self.write_archive(); self.run_final()
        self.assertFalse(marker.exists())
        self.assertIn(b'Genuine source bytes.', self.page.read_bytes())

    def test_second_renderer_failure_precedes_all_writes(self):
        other = self.page.parent/'zfail.3'; other.symlink_to(other.name)
        self.write_archive([('doc/crypto/zfail.pod', POD.replace(b'tiny', b'zfail'))])
        wrapper = self.directory/'selected-renderer.pl'
        wrapper.write_text('exit 7 if $ARGV[1] eq "zfail"; do '+json.dumps(renderer)+'; die $@ if $@;')
        self.config['manual']['renderHelper'] = str(wrapper)
        before = self.snapshot()
        with self.assertRaises(ValueError) as failure:
            self.run_final()
        self.assertIn('7', str(failure.exception))
        self.assertEqual(before, self.snapshot())

    def test_renderer_nonzero_and_diagnostics(self):
        for program in ['print "payload"; exit 7;', 'print STDERR "diagnostic"; print "payload";',
                        'print "bad\\0payload";', 'print "invalid text";']:
            with self.subTest(program=program):
                fake = self.directory/'renderer.pl'; fake.write_text(program)
                self.config['manual']['renderHelper'] = str(fake)
                self.rejects()


unittest.main()

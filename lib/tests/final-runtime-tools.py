"""Tiny offline fixtures for source plans; never compile/execute target packages.

Input is the JSON from final-runtime-tools.nix. Run actual selected copy and
standalone store-file finalizers over invented bytes, not realized app payloads.
"""
import ast
import hashlib
import json
import os
from pathlib import Path
import shlex
import struct
import subprocess
import sys
import tempfile

rows = json.loads(Path(sys.argv[1]).read_text())['rows']
fixture_perl = sys.argv[2]
checks = {}

def command(row, name, variant='fixtureCommands'):
    return next(s['run'] for s in row[variant] if s['name'] == name)

def run(script, cwd, env, success=True):
    p = subprocess.run(['bash', '-euc', script], cwd=cwd, env={**os.environ, **env}, capture_output=True)
    if (p.returncode == 0) != success:
        raise AssertionError((script, p.returncode, p.stdout.decode(), p.stderr.decode()))
    return p

def snapshot(root):
    return {str(p.relative_to(root)): ('link', os.readlink(p)) if p.is_symlink() else ('file', p.read_bytes())
            for p in root.rglob('*') if p.is_symlink() or p.is_file()}

def elf(rodata, data=b''):
    # A tiny ELF64 section fixture, with no code/program/dynamic payload.
    names = b'\0.shstrtab\0.rodata\0.data\0'
    blob = bytearray(64)
    parts = []
    for payload in (names, rodata, data):
        offset = len(blob); blob.extend(payload); parts.append((offset, len(payload)))
    blob.extend(b'\0' * (-len(blob) % 8)); table = len(blob)
    sections = [(0, 0, 0, 0, 0, 0, 0, 0, 0, 0)]
    for name, kind, flags, (offset, size) in zip((1, 11, 19), (3, 1, 1), (0, 2, 3), parts):
        sections.append((name, kind, flags, 0, offset, size, 0, 0, 1, 0))
    for s in sections:
        blob.extend(struct.pack('<IIQQQQIIQQ', *s))
    blob[:64] = struct.pack('<16sHHIQQQIHHHHHH', b'\x7fELF\x02\x01\x01'+b'\0'*9,
                            3, 62, 1, 0, 0, table, 0, 64, 0, 0, 64, 4, 1)
    return bytes(blob)

with tempfile.TemporaryDirectory(prefix='tvp-runtime-tools-fixtures-') as td:
    workspace = Path(td)
    for name, row in rows.items():
        for s in row['commands'] + row['upstreamCommands'] + row['runtimeCommands']:
            subprocess.run(['bash', '-n'], input=s['run'].encode(), check=True, capture_output=True)
        checks[name + '.shellSyntax'] = True
        work = workspace / name; work.mkdir()
        a, f = work/'aaaaaaaa', work/'ffffffff'
        a.mkdir(); (a/'bin').mkdir(); (a/'nix-support').mkdir()
        (a/'nix-support/source-date-epoch').write_text('1\n')
        env = {'out': str(f), 'TVP_ARTIFACT_ROOT': str(a), 'TVP_SOURCE_ROOT': str(work), 'CC': '/offline/fixture/cc'}
        if name == 'go_1_27_3':
            (a/'share/go/bin').mkdir(parents=True)
            payload = b'\x7fELF\0Go build ID: fixture bytes\n'
            (a/'share/go/bin/go').write_bytes(payload)
            (a/'bin/go').symlink_to('../share/go/bin/go')
            run(command(row, 'output.copy-artifacts'), work, env)
            assert (f/'bin/go').read_bytes() == payload
            assert os.readlink(f/'bin/go') == '../share/go/bin/go'
            assert hashlib.sha256((f/'share/go/bin/go').read_bytes()).digest() == hashlib.sha256(payload).digest()
            assert (work/'source-date-epoch').read_text() == '1\n'
            checks[name+'.selectedCopyPreservesNativeBytesAndLinks'] = True
            continue
        if name == 'git_2_56_0':
            source = work/'source'; source.mkdir()
            original_make = ('SHELL_PATH_CQ = "$(SHELL_PATH)"\n'
                'all:: $(TEST_PROGRAMS) $(test_bindir_programs) $(UNIT_TEST_PROGS) $(CLAR_TEST_PROG)\n')
            (source/'Makefile').write_text(original_make)
            run(command(row, 'git.source-slots'), source, env)
            prepared = (source/'Makefile').read_text()
            assert r'\0TVP_ORDINARY_SHELL_' + 'X'*238 in prepared
            assert 'all:: $(TEST_PROGRAMS)' not in prepared
            bad = original_make + 'SHELL_PATH_CQ = "duplicate"\n'
            (source/'Makefile').write_text(bad)
            run(command(row, 'git.source-slots'), source, env, success=False)
            assert (source/'Makefile').read_text() == bad
            checks[name+'.selectedSourceSlotGuard'] = True
        final_name = {'git_2_56_0':'git.bind-runtime', 'less_710':'less.transport', 'nodejs_26_13_0':'nodejs.relocate'}[name]
        selected = command(row, final_name, 'fixtureCommands')
        args = shlex.split(selected)
        if name == 'nodejs_26_13_0':
            (a/'include/node').mkdir(parents=True)
            (a/'include/node/config.gypi').write_text("# fixture\n{'variables': {'node_prefix': '/tvp/node', 'unchanged': 42}}\n")
            (a/'lib/node_modules/npm').mkdir(parents=True)
            (a/'lib/node_modules/npm/entry.js').write_text(f'#!{a}/bin/node\n')
            (a/'bin/node').write_bytes(b'\x7fELF\0serialized builtin JS stays intact\0')
            original = (a/'bin/node').read_bytes()
        else:
            binding = json.loads(args[5])
            shell = binding['shell'][0] if isinstance(binding, dict) else binding[0]
            slot = shell.encode() + b'\0TVP_ORDINARY_SHELL_' + b'X'*238
            native = 'git' if name == 'git_2_56_0' else 'less'
            ro = slot+b'\0'
            data = b''
            if native == 'less':
                ro += str(a).encode()+b'/bin/lessecho\0'+str(a).encode()+b'/etc/sysless\0'+str(a).encode()+b'/bin/.sysless\0'
                data = b'LESS_OSC8_OPEN_ANY\0\x81-'+str(a).encode()+b'/bin/less-osc8-open\0'
            (a/('bin/'+native)).write_bytes(elf(ro, data))
            os.link(a/('bin/'+native), a/('bin/'+native+'-alias')) if native == 'git' else None
            if native == 'git':
                (a/'libexec/git-core').mkdir(parents=True)
                os.link(a/'bin/git', a/'libexec/git-core/git-add')
                (a/'bin/git-helper').write_text('#!'+binding['perl'][0]+'\n')
                header = (Path(__file__).resolve().parents[2]/'pkgs/build-tools/git/tests/fixtures/runtime-prefix.pl').read_text()
                for old, new in [('@GITEXECDIR_REL@','libexec/git-core'),('@PERLLIBDIR_REL@','share/perl5'),('@LOCALEDIR_REL@','share/locale'),('@PATHSEP@',':')]:
                    header=header.replace(old,new)
                cvsserver=a/'bin/git-cvsserver'
                cvsserver.write_text('#!'+binding['perl'][0]+'\n'+header+'\ndie "ignored GITPERLLIB" if exists $ENV{GITPERLLIB} && !grep { $_ eq $ENV{GITPERLLIB} } @INC;\nprint __git_system_path("share/perl5"), "\\n", $Git::I18N::TEXTDOMAINDIR, "\\n";\n')
                os.link(cvsserver,a/'libexec/git-core/git-cvsserver')
                (a/'share/perl5').mkdir(parents=True)
                (a/'share/locale').mkdir()
        run(command(row, 'output.copy-artifacts'), work, env)
        artifact_before = snapshot(a)
        if name == 'git_2_56_0':
            clean={k:v for k,v in os.environ.items() if k not in ('GIT_EXEC_PATH','GITPERLLIB','PERL5LIB','PERLLIB')}
            original_entry=subprocess.run([fixture_perl,str(f/'bin/git-cvsserver')],env=clean,text=True,capture_output=True)
            assert original_entry.returncode!=0 and 'Invalid system path' in original_entry.stderr
            checks[name+'.originalBinHeaderReproducesFailure'] = True
        # The selected helper paths are independent store files, with explicit
        # primitive arguments; no source-directory sibling imports available.
        run(selected, work, env)
        assert snapshot(a) == artifact_before
        assert all(str(a).encode() not in v[1] if v[0]=='file' else str(a) not in v[1] for v in snapshot(f).values())
        if name == 'nodejs_26_13_0':
            assert (f/'bin/node').read_bytes() == original
            config = ast.literal_eval((f/'include/node/config.gypi').read_text())
            assert config == {'variables': {'node_prefix': str(f), 'unchanged': 42}}
        else:
            b = (f/('bin/'+native)).read_bytes()
            assert b'TVP_ORDINARY_SHELL_' not in b
            if native == 'git':
                assert os.path.samefile(f/'bin/git', f/'libexec/git-core/git-add')
                assert (f/'bin/git-helper').read_text().startswith('#!'+binding['perl'][1]+'\n')
                assert os.path.samefile(f/'bin/git-cvsserver',f/'libexec/git-core/git-cvsserver')
                clean={k:v for k,v in os.environ.items() if k not in ('GIT_EXEC_PATH','GITPERLLIB','PERL5LIB','PERLLIB')}
                for entry in ['bin/git-cvsserver','libexec/git-core/git-cvsserver']:
                    for overrides in [{},{'GIT_EXEC_PATH':str(f/'libexec/git-core')},{'GITPERLLIB':str(f/'share/perl5')}]:
                        p=subprocess.run([fixture_perl,str(f/entry)],env={**clean,**overrides},text=True,capture_output=True)
                        assert p.returncode==0,(entry,overrides,p.stderr)
                        assert p.stdout.splitlines()==[str(f/'share/perl5'),str(f/'share/locale')],(entry,p.stdout)
                # A distinct explicit exec prefix must take precedence over
                # the script's bin/libexec location, for both derived paths.
                override=work/'override';(override/'share/perl5').mkdir(parents=True)
                for entry in ['bin/git-cvsserver','libexec/git-core/git-cvsserver']:
                    p=subprocess.run([fixture_perl,str(f/entry)],env={**clean,'GIT_EXEC_PATH':str(override/'libexec/git-core')},text=True,capture_output=True)
                    assert p.returncode==0,p.stderr
                    assert p.stdout.splitlines()==[str(override/'share/perl5'),str(override/'share/locale')]
                    p=subprocess.run([fixture_perl,str(f/entry)],env={**clean,'GITPERLLIB':str(override/'share/perl5')},text=True,capture_output=True)
                    assert p.returncode==0,p.stderr
                    assert p.stdout.splitlines()==[str(f/'share/perl5'),str(f/'share/locale')]
                checks[name+'.cvsserverBinLibexecAndOverrides'] = True
            else:
                assert b'LESS_OSC8_OPEN_ANY\0\x81-'+str(f).encode()+b'/bin/less-osc8-open\0' in b
        checks[name+'.selectedCopyAndStandaloneFinalizer'] = True
        # Whole-namespace rejection must leave earlier valid data untouched.
        import shutil
        shutil.rmtree(f)
        run(command(row, 'output.copy-artifacts'), work, env)
        (f/'zz-unknown').write_bytes(b'\0unknown '+str(a).encode()+b'/path\0')
        before = snapshot(f)
        run(selected, work, env, success=False)
        assert snapshot(f) == before
        checks[name+'.unknownPayloadRejectsBeforeWrites'] = True
        if name == 'nodejs_26_13_0':
            (f/'zz-unknown').unlink()
            (f/'lib/node_modules/npm/unknown.json').write_text(json.dumps({'unreviewed': str(a)}))
            before = snapshot(f)
            run(selected, work, env, success=False)
            assert snapshot(f) == before
            checks[name+'.structuredPayloadRejectsBeforeWrites'] = True
        else:
            (f/'zz-unknown').unlink()
            if native == 'less':
                (f/'bin/less').write_bytes(elf(slot+b'\0'+str(a).encode()+b'/unknown\0'))
            else:
                # A marker outside its declared slot is never accepted.
                (f/'bin/git').write_bytes(elf(b'wrong\0TVP_ORDINARY_SHELL_'+b'X'*238+b'\0'))
            before = snapshot(f)
            run(selected, work, env, success=False)
            assert snapshot(f) == before
            checks[name+'.unknownNativeShapeRejectsBeforeWrites'] = True
            if native == 'git':
                shutil.rmtree(f)
                run(command(row, 'output.copy-artifacts'), work, env)
                cvsserver=f/'bin/git-cvsserver'
                original=cvsserver.read_bytes()
                changed=original.replace(br'(my $prefix = $exec_path) =~ s/\Q$gitexecdir_relative\E$//;',b'UNRECOGNIZED_RUNTIME_HEADER')
                assert changed!=original
                cvsserver.write_bytes(changed)
                before=snapshot(f)
                run(selected,work,env,success=False)
                assert snapshot(f)==before
                checks[name+'.unknownCvsserverHeaderRejectsBeforeWrites'] = True
print(json.dumps({'success': True, 'checks': checks, 'qualification': 'synthetic source/copy/format fixtures only; emitted layouts UNRUN'}, indent=2))

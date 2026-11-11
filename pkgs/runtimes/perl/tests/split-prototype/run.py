"""Finite cached-output experiment, deliberately outside production recipes.

Usage: selected-python -B run.py CONFIG.json EVIDENCE_DIRECTORY
All tools and the one already-valid cached Perl output are explicit in CONFIG.
No Nix build, compiler bootstrap, server, background task or network access.
This tests equal-size rebasing and an intentionally failing shorter-string
control. It does NOT supply an installable Perl finalizer.
"""
import hashlib
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import tempfile

from elf import inspect
from source import inventory, text


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main():
    config = json.loads(Path(sys.argv[1]).read_text())
    evidence = Path(sys.argv[2]).resolve(strict=True)
    cache = Path(config['cache'])
    if not str(cache).startswith('/nix/store/') or str(cache).endswith('.drv'):
        raise ValueError('explicit cached output required')
    # Never confuse a registered descriptor with a valid output.
    valid = subprocess.run(['nix-store', '--check-validity', '--print-invalid', '--stdin'],
                           input=str(cache) + '\n', text=True, capture_output=True)
    (evidence / 'cache-validity.json').write_text(json.dumps({
        'exit': valid.returncode, 'stdout': valid.stdout, 'stderr': valid.stderr}) + '\n')
    if valid.returncode != 0 or valid.stdout:
        raise ValueError('cached output is missing; do not realize it')
    tools = config['tools']
    env = {'PATH': ':'.join(str(Path(tools[t]).parent) for t in ('cc', 'make', 'readelf', 'cp')),
           'HOME': str(evidence), 'LC_ALL': 'C'}
    calls = []

    def run(label, argv, cwd, *, expected=None, fail=False):
        result = subprocess.run(list(map(str, argv)), cwd=cwd, env=env, capture_output=True)
        (evidence / (label + '.stdout')).write_bytes(result.stdout)
        (evidence / (label + '.stderr')).write_bytes(result.stderr)
        calls.append({'label': label, 'argv': list(map(str, argv)), 'cwd': str(cwd),
                      'exit': result.returncode, 'expectedFailure': fail})
        if fail:
            if result.returncode == 0:
                raise ValueError(('negative control unexpectedly passed', label))
        elif result.returncode != 0 or (expected is not None and result.stdout != expected):
            raise ValueError(('prototype command failed', label, result.returncode))
        return result

    old = str(cache).encode()
    # Temporary roots have canonical parents and exactly controlled byte lengths.
    # They are never registered as Nix outputs or retained by realization.
    work = Path(tempfile.mkdtemp(prefix='tvp-perl-'))
    report = {'cache': str(cache), 'config': config, 'calls': calls, 'status': 'INCOMPLETE'}
    try:
        for variant, delta in [('equal', 0), ('short', -10)]:
            prefix = work / (variant + '-' + 'x' * (len(old) + delta - len(str(work)) - len(variant) - 2))
            new = str(prefix).encode()
            assert len(new) == len(old) + delta
            run(variant + '-copy', [tools['cp'], '-a', '--no-preserve=ownership', cache, prefix], work)
            run(variant + '-writable', [tools['chmod'], '-R', 'u+w', prefix], work)
            root, files, groups, links = inventory(str(prefix))
            # Whole-tree classification before writes. Known metadata is always
            # text; NUL corruption must not redirect it to binary handling.
            changes, mappings, rpaths = {}, {}, []
            for group in groups:
                name = group[0]
                path = files[name]
                data = path.read_bytes()
                metadata = (path.name in ('Config.pm', 'Config_heavy.pl', '.packlist')
                            or '/CORE/' in '/' + name and path.suffix in ('.h', '.c'))
                if metadata:
                    text(data, name)
                if data.startswith(b'\x7fELF'):
                    hits = inspect(path, old, tools['readelf'])
                    mappings[name] = hits
                    rodata = [h for h in hits if h['section'] == '.rodata']
                    for hit in hits:
                        if hit['section'] == '.dynstr':
                            continue  # Only the selected patchelf changes dynamic strings.
                        if (hit['section'] != '.rodata' or not hit['readonlyAllocated']
                                or not hit['prefixAtStringStart'] or hit['stringEnd'] < 0):
                            raise ValueError(('unsupported prefix location', name, hit))
                        s = hit['string'].encode()
                        if not s.startswith(old + b'/lib/'):
                            raise ValueError(('not an installed Perl library pathname', name, s))
                    for hit in reversed(rodata):
                        start, end = hit['stringStart'], hit['stringEnd']
                        s = data[start:end]
                        replacement = new + s[len(old):]
                        # Isolated negative experiment, not a safe relocation API:
                        # this retains file offsets but may violate compiled lengths.
                        data = data[:start] + replacement.ljust(len(s), b'\0') + data[end:]
                    changes[name] = data
                    dynamic = run(variant + '-rpath-' + str(len(rpaths)),
                                  [tools['patchelf'], '--print-rpath', path], work)
                    rpaths.append((name, dynamic.stdout.strip().replace(old, new)))
                elif old in data:
                    text(data, name)
                    changes[name] = data.replace(old, new)
            for group in groups:
                name = group[0]
                if name in changes:
                    with files[name].open('r+b') as stream:
                        stream.write(changes[name])
                        stream.truncate()
            for name, target in links.items():
                if old in target.encode():
                    files_path = prefix / name
                    files_path.unlink()
                    files_path.symlink_to(target.replace(str(cache), str(prefix)))
            for i, (name, rpath) in enumerate(rpaths):
                run(variant + '-set-rpath-' + str(i),
                    [tools['patchelf'], '--set-rpath', rpath.decode(), prefix / name], work)
            # Exclude the old prefix from ALL bytes and symlink targets.
            residual = []
            for p in prefix.rglob('*'):
                if p.is_symlink():
                    if old in os.readlink(p).encode():
                        residual.append(str(p.relative_to(prefix)))
                elif p.is_file() and old in p.read_bytes():
                    residual.append(str(p.relative_to(prefix)))
            assert not residual, residual
            (evidence / (variant + '-mapping.json')).write_text(json.dumps(mappings, indent=2) + '\n')
            perl = prefix / 'bin/perl'
            # No Config/core-module loading is needed to expose corrupt bare @INC.
            result = run(variant + '-bare-inc', [perl, '-e',
                         'print join("\\n", map { length($_).":".unpack("H*",$_) } @INC)'], work)
            inc = [bytes.fromhex(line.split(b':', 1)[1].decode()) for line in result.stdout.split(b'\n')]
            clean = bool(inc) and all(p.startswith(new + b'/lib/') and b'\0' not in p for p in inc)
            report[variant] = {'root': str(prefix), 'lengthDelta': delta, 'bareIncClean': clean,
                               'oldPrefixExcluded': True, 'rodataHits': sum(
                                   len([h for h in hits if h['section'] == '.rodata']) for hits in mappings.values())}
            if variant == 'short':
                assert not clean, 'shorter-string negative control did not reproduce'
                run('short-core-lookup', [perl, '-MList::Util=sum', '-e', 'print sum(1,2,39)'], work, fail=True)
                continue
            assert clean
            run('equal-core-lookup', [perl, '-MList::Util=sum', '-e', 'print sum(1,2,39)'], work, expected=b'42')
            run('equal-module-paths', [perl, '-MList::Util', '-MConfig', '-e',
                'for(values %INC) { die "module escaped final prefix: $_" unless index($_,$ARGV[0]."/")==0 } print "module-paths-ok"',
                prefix], work, expected=b'module-paths-ok')
            run('equal-config', [perl, '-MConfig', '-e',
                'print join("\\n", map { "$_=$Config{$_}" } qw(prefix privlib archlib useshrplib cc make libperl ccflags)),"\\n"'], work)
            # Config and bare @INC must point into the disposable final tree.
            run('equal-config-paths', [perl, '-MConfig', '-e',
                'die unless $Config{prefix} eq $ARGV[0]; for(qw(privlib archlib)) { die unless index($Config{$_},$ARGV[0]."/")==0 } print "config-ok"', prefix], work, expected=b'config-ok')
            xs = work / 'xs'; xs.mkdir()
            (xs / 'Makefile.PL').write_text("use ExtUtils::MakeMaker; WriteMakefile(NAME=>'TVPSplit', VERSION=>'0.01');\n")
            (xs / 'TVPSplit.pm').write_text("package TVPSplit; our $VERSION='0.01'; require XSLoader; XSLoader::load('TVPSplit',$VERSION); 1;\n")
            (xs / 'TVPSplit.xs').write_text('#include "EXTERN.h"\n#include "perl.h"\n#include "XSUB.h"\nMODULE = TVPSplit PACKAGE = TVPSplit\n\nint\nanswer()\n    CODE:\n        RETVAL = 42;\n    OUTPUT:\n        RETVAL\n')
            run('equal-xs-configure', [perl, 'Makefile.PL', 'CC=' + tools['cc'], 'LD=' + tools['cc']], xs)
            run('equal-xs-build', [tools['make'], '-j2'], xs)
            run('equal-xs-load', [perl, '-Iblib/lib', '-Iblib/arch', '-MTVPSplit', '-e', 'print TVPSplit::answer()'], xs, expected=b'42')
            embed = work / 'embed'; embed.mkdir()
            (embed / 'embed.c').write_text('#include <EXTERN.h>\n#include <perl.h>\nEXTERN_C void xs_init(pTHX);\nstatic PerlInterpreter *my_perl;\nint main(int argc,char **argv,char **env) {\nchar *program[]={"","-e","use List::Util qw(sum); print sum(1,2,39)"};\nPERL_SYS_INIT3(&argc,&argv,&env);my_perl=perl_alloc();perl_construct(my_perl);\nint r=perl_parse(my_perl,xs_init,3,program,NULL);if(!r)r=perl_run(my_perl);\nperl_destruct(my_perl);perl_free(my_perl);PERL_SYS_TERM();return r;}\n')
            run('equal-xsinit', [perl, '-MExtUtils::Embed', '-e', 'xsinit'], embed)
            opts = run('equal-embed-opts', [perl, '-MExtUtils::Embed', '-e', 'ccopts', '-e', 'ldopts'], embed)
            import shlex
            flags = shlex.split(opts.stdout.decode())
            run('equal-embed-build', [tools['cc'], 'embed.c', 'perlxsi.c', *flags, '-o', 'embed'], embed)
            needed = run('equal-embed-needed', [tools['readelf'], '-d', 'embed'], embed)
            assert b'NEEDED' in needed.stdout and b'libperl.so' in needed.stdout
            run('equal-embed-run', [embed / 'embed'], embed, expected=b'42')
            # Preserve source fixtures and produced small ABI witnesses, not a
            # mutable copy of a complete installed package.
            for name, directory in [('xs', xs), ('embed', embed)]:
                shutil.copytree(directory, evidence / name, symlinks=True)
        report['status'] = 'EQUAL_LENGTH_CACHED_COPY_PASS_SHORTER_PREFIX_FAIL'
        report['limitations'] = [
            'Cached retained 5.42.3 only; not a new owned artifact or final producer.',
            'Equal length is not the owned builder shape: its artifact name is ten bytes longer.',
            'Shortening .rodata strings leaves compiled @INC lengths stale in this cached interpreter.',
            'PERL_RELOCATABLE_INCPUSH was not enabled in the cached interpreter; no new Perl was built.',
            'ELF section mapping does not prove absence of interior pointers/string pooling.',
            'No nine-release production finalizer, override/reuse proof, upstream suite or admission.']
    finally:
        (evidence / 'report.json').write_text(json.dumps(report, indent=2, sort_keys=True) + '\n')
        shutil.rmtree(work)


if __name__ == '__main__':
    main()

"""Adversarial all-before-write source/output contracts for ordinary Zlib."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import signal
import shutil

source_helper, output_helper, shell, perl, readelf, patchelf = sys.argv[1:7]
copy_script, suffix_script, artifact = sys.argv[7:]
def bounded(args, **kwargs):
    timeout = kwargs.pop('timeout', 10)
    check = kwargs.pop('check', False)
    capture = kwargs.pop('capture_output', False)
    p = subprocess.Popen(args, start_new_session=True,
                         stdout=subprocess.PIPE if capture else None,
                         stderr=subprocess.PIPE if capture else None, **kwargs)
    try:
        out, err = p.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        os.killpg(p.pid, signal.SIGKILL)
        p.communicate()
        raise AssertionError(('deadline exceeded; descendants reaped', args))
    if check and p.returncode:
        raise AssertionError(('command failed', args, p.returncode, out, err))
    return subprocess.CompletedProcess(args, p.returncode, out, err)
base = Path.cwd()

def digest(root):
    rows = []
    for directory, dirs, files in os.walk(root, followlinks=False):
        for name in sorted(dirs + files):
            p = Path(directory) / name
            st = p.lstat()
            value = os.readlink(p) if p.is_symlink() else hashlib.sha256(p.read_bytes()).hexdigest() if p.is_file() else str(st.st_mode)
            rows.append((str(p.relative_to(root)), value, st.st_mode, st.st_ino, st.st_nlink))
    return rows

cases = ['source-alias', 'source-directory', 'source-hardlink', 'source-fifo',
         'source-collision', 'source-unknown', 'source-renamed-unknown', 'source-anchor',
         'source-nul-header', 'source-nul-body', 'source-configure-nul',
         'output-readelf-exit', 'output-readelf-stderr', 'output-readelf-malformed', 'output-patchelf-exit', 'output-patchelf-stderr', 'output-patchelf-malformed', 'output-alias', 'output-directory', 'output-hardlink', 'output-fifo',
         'output-collision', 'output-unknown', 'output-renamed-unknown', 'output-nested-fifo-alias',
         'output-manual-collision', 'output-malformed-elf', 'output-directory-as-file', 'output-nul-frontend']
cases += ['output-alias-' + area + '-' + kind for area in ('bin', 'lib', 'libexec')
          for kind in ('shell', 'unknown', 'nul', 'chain')]
for case in cases:
    root = base / case
    root.mkdir()
    external = base / (case + '-external')
    external.write_text('unchanged')
    if case.startswith('source'):
        (root/'configure').write_text('#!/bin/sh\n/usr/bin/file\n')
        (root/'build-aux').mkdir()
        (root/'test').mkdir()
        (root/'build-aux/ltmain.sh').write_text("#!/bin/sh\neval sys_lib_search_path=foo\n")
        target = root/'test/helper'
        target.write_text('#!/bin/sh\necho original\n')
        if case == 'source-alias': target.unlink(); target.symlink_to(external)
        if case == 'source-directory': (root/'test').rename(root/'fixtures'); (root/'test').symlink_to('fixtures')
        if case == 'source-hardlink': target.unlink(); os.link(external, target)
        if case == 'source-fifo': target.unlink(); os.mkfifo(target)
        if case == 'source-collision': (root/'configure.tvp-prepare').symlink_to(external)
        if case in ('source-unknown','source-renamed-unknown'): target.write_text('#!/usr/bin/python3\npass\n')
        if case == 'source-renamed-unknown': target.rename(root/'test/unexpected.dat')
        if case == 'source-anchor': (root/'build-aux/ltmain.sh').write_text('#!/bin/sh\nmissing anchor\n')
        if case == 'source-nul-header': target.write_bytes(b'#!/bin/sh\0\necho original\n')
        if case == 'source-nul-body': target.write_bytes(b'#!/bin/sh\necho\0 original\n'); target.rename(root/'test/renamed.dat')
        if case == 'source-configure-nul': (root/'configure').write_bytes(b'#!/bin/sh\n: \0\n')
        args=[sys.executable,'-B',source_helper,shell,json.dumps({'selections':['configure','build-aux','test'],'edits':[{'path':'build-aux/ltmain.sh','before':'eval sys_lib_search_path=foo','after':'validated','count':1}]})]
    else:
        copy_env = {**os.environ, 'out':str(root), 'TVP_ARTIFACT_ROOT':artifact, 'TVP_SOURCE_ROOT':str(base)}
        bounded([shell,'-euo','pipefail',copy_script],env=copy_env,check=True)
        (root/'bin').mkdir(exist_ok=True); (root/'lib').mkdir(exist_ok=True); (root/'share/man/man1').mkdir(parents=True,exist_ok=True)
        target=root/'bin/helper'; target.write_text('#!/bin/sh\necho original\n'); target.chmod(0o755)
        if case == 'output-alias': (root/'lib/archive.a').symlink_to('../bin/helper')
        if case == 'output-directory': (root/'bin').rename(root/'commands'); (root/'bin').symlink_to('commands')
        if case == 'output-hardlink': os.link(external,root/'lib/escape')
        if case == 'output-fifo': os.mkfifo(root/'lib/pipe')
        if case == 'output-nested-fifo-alias':
            (root/'lib/nested').mkdir()
            os.mkfifo(root/'lib/nested/pipe')
            (root/'bin/alias').symlink_to('../lib/nested/pipe')
        if case == 'output-collision': (root/'bin/helper.tvp-relocating').symlink_to(external)
        if case in ('output-unknown','output-renamed-unknown'): target.write_text('#!/usr/bin/python3\npass\n')
        if case == 'output-renamed-unknown': target.rename(root/'bin/unexpected.dat')
        if case == 'output-manual-collision': (root/'share/man/man1/a.1').write_text('one'); (root/'share/man/man1/a.1.gz').write_text('two')
        if case == 'output-directory-as-file': target.unlink(); (root/'bin').rmdir(); (root/'bin').symlink_to('../'+external.name)
        if case == 'output-nul-frontend': target.write_bytes(b'#!/usr/bin/python3\n\0pass\n')
        if case == 'output-malformed-elf': target.write_bytes(b'\x7fELF'+b'\0'*60)
        if case.startswith('output-alias-'):
            _, _, area, kind = case.split('-')
            (root / area).mkdir(exist_ok=True)
            script = root / 'share/hidden'
            script.write_bytes(b'#!/usr/bin/python3\npass\n' if kind == 'unknown' else
                               b'#!/bin/sh\necho\0 original\n' if kind == 'nul' else b'#!/bin/sh\n: ${SHELL:=/bin/sh}\n')
            script.chmod(0o755)
            if kind == 'chain':
                (root/'share/indirect').symlink_to('hidden')
            (root / area / 'alias').symlink_to('../share/indirect' if kind == 'chain' else '../share/hidden')
        config={'readelf':readelf,'shell':shell,'buildShell':'/bin/sh','paths':[], 'requiredDirectories':['bin','lib','share/man'],'requiredFiles':[], 'requiredRegular':['lib/archive.a'],'libtoolData':[]}
        if case.startswith(('output-readelf-', 'output-patchelf-')):
            target.write_bytes(next(Path(artifact).rglob('lib*.so')).read_bytes())
            tool = base / (case + '-tool')
            kind = case.rsplit('-', 1)[1]
            tool.write_text('#!' + shell + '\n' + ('exit 1\n' if kind == 'exit' else 'echo warning >&2\n' if kind == 'stderr' else 'printf \"malformed\\nextra\\n\"\n'))
            tool.chmod(0o755)
            if 'readelf' in case: config['readelf'] = str(tool)
            else: selected_patchelf = str(tool)
        else: selected_patchelf = patchelf
        if case.startswith('output-readelf-'): selected_patchelf = patchelf
        args=[sys.executable,'-B',output_helper,str(root),'/nix/store/'+'x'*32+'-a-long-artifact-output',selected_patchelf,json.dumps(config)]
    before=digest(root); outside=external.read_bytes()
    p=bounded(args,cwd=root,capture_output=True,timeout=10)
    assert p.returncode and before==digest(root) and external.read_bytes()==outside, (case,p.stdout,p.stderr)
    if case.startswith('output'):
        content = Path(suffix_script).read_text()
        if case.startswith('output-readelf-'): content=content.replace(readelf,str(tool))
        if case.startswith('output-patchelf-'): content=content.replace(patchelf,str(tool))
        per_case=base/(case+'-suffix.sh');per_case.write_text(content)
        p=bounded([shell,'-euo','pipefail',str(per_case)],env=copy_env,capture_output=True,timeout=10)
        assert p.returncode and before==digest(root) and external.read_bytes()==outside, ('full suffix',case,p.stdout,p.stderr)
    print('PASS',case, file=sys.stderr)

# Run the actual copy record, then all remaining finalization records against a
# public alias fixture. Copying legitimately writes; relocation must reject the
# copied tree before any further changes, regardless of later audit behavior.
root = base / 'complete-suffix-alias'
env = {**os.environ, 'out': str(root), 'TVP_ARTIFACT_ROOT': artifact,
       'TVP_SOURCE_ROOT': str(base)}
subprocess.run([shell, '-euo', 'pipefail', copy_script], env=env, check=True)
(root/'bin').mkdir(exist_ok=True)
(root/'share').mkdir(exist_ok=True)
(root/'share/hidden').write_text('#!/bin/sh\n: ${SHELL:=/bin/sh}\n')
(root/'share/hidden').chmod(0o755)
(root/'bin/alias').symlink_to('../share/hidden')
before = digest(root)
p = bounded([shell, '-euo', 'pipefail', suffix_script], env=env, capture_output=True, timeout=10)
assert p.returncode and b'selected executable alias' in p.stderr and before == digest(root), (p.stdout, p.stderr)
print('PASS complete-suffix-alias', file=sys.stderr)

print('ok')

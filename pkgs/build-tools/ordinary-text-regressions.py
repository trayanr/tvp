"""Run frontend counterexamples and a real recipe's complete final suffix."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

source, output, audit, common, readelf, patchelf, shell, perl, suffix, dynamic = sys.argv[1:]
top = Path.cwd() / 'regressions'
top.mkdir()

def snapshot(root):
    return {str(p.relative_to(root)): os.readlink(p) if p.is_symlink() else
            hashlib.sha256(p.read_bytes()).hexdigest() for p in root.rglob('*')
            if p.is_file() or p.is_symlink()}

for name in ('probe.py', 'probe', 'alias.sh'):
    root = top / name
    (root / 'tests').mkdir(parents=True)
    (root / 'configure').write_text('#!/bin/sh\nexit 0\n')
    probe = root / 'tests' / name
    if name == 'alias.sh':
        (root / 'outside-selection').mkdir()
        target = root / 'outside-selection' / 'helper'
        target.write_text('#!/bin/zsh\nexit 0\n')
        probe.symlink_to('../outside-selection/helper')
    else:
        probe.write_text(('#!/usr/bin/python3' if name.endswith('.py') else '#!/bin/zsh') + '\nexit 0\n')
        probe.chmod(0o755)
    before = snapshot(root)
    r = subprocess.run([sys.executable, '-B', source, shell, perl, '["tests"]'], cwd=root, capture_output=True)
    assert r.returncode and snapshot(root) == before, (name, r.stderr)

config = {'readelf': readelf, 'shell': shell, 'buildShell': '/bin/sh', 'paths': []}
for interpreter in ('/bin/zsh', '/usr/bin/python3'):
    root = top / Path(interpreter).name
    (root / 'libexec').mkdir(parents=True)
    (root / 'metadata').write_text('/old/artifact-prefix/' + 'a' * 200)
    (root / 'libexec/helper').write_text('#!' + interpreter + '\nexit 0\n')
    before = snapshot(root)
    r = subprocess.run([sys.executable, '-B', output, str(root), '/old/artifact-prefix/' + 'a' * 200,
                        patchelf, json.dumps(config)], capture_output=True)
    assert r.returncode and snapshot(root) == before, (interpreter, r.stderr)
root = top / 'libexec-shell'
(root / 'libexec').mkdir(parents=True)
helper = root / 'libexec/helper'
helper.write_text('#!/bin/sh\n: ${SHELL:=/bin/sh}\nprintf "%s\\n" "$SHELL"\n')
helper.chmod(0o755)
subprocess.run([sys.executable, '-B', output, str(root), '/old/artifact-prefix/' + 'a' * 200,
                patchelf, json.dumps(config)], check=True, stdout=subprocess.PIPE)
assert helper.read_text().startswith('#!' + shell + '\n')
assert subprocess.check_output([str(helper)], env={'PATH': ''}).decode().strip() == shell

# Exercise the actual copy/relocate/shebang/strip/RPATH/development/final-audit
# records selected by Grep, rather than testing the relocation helpers alone.
artifact = top / ('artifact-' + 'a' * 180)
(artifact / 'bin').mkdir(parents=True)
(artifact / 'lib').mkdir()
binary = artifact / 'bin/probe'
shutil.copyfile(dynamic, binary)
binary.chmod(0o755)
original = subprocess.check_output([patchelf, '--print-rpath', binary]).decode().removesuffix('\n')
spelling = '$ORIGIN/../lib:${ORIGIN}/../lib:$LIB/../$PLATFORM::'
subprocess.run([patchelf, '--set-rpath', spelling + original, binary], check=True)
final = top / 'final'
env = {**os.environ, 'out': str(final), 'TVP_ARTIFACT_ROOT': str(artifact),
       'TVP_SOURCE_ROOT': str(top), 'NIX_BUILD_TOP': str(top / 'build'), 'TMPDIR': str(top / 'tmp')}
r = subprocess.run([shell, '-euo', 'pipefail', suffix], env=env, capture_output=True)
assert r.returncode == 0, r.stderr
actual = subprocess.check_output([patchelf, '--print-rpath', final / 'bin/probe']).decode().removesuffix('\n')
assert spelling in actual, actual
subprocess.run([str(final / 'bin/probe')], check=True)
cfg = {'paths': ['bin'], 'elfKinds': None, 'readelf': readelf, 'patchelf': patchelf}
for bad in (str(top / 'build'), str(artifact), '$UNKNOWN/elsewhere'):
    subprocess.run([patchelf, '--set-rpath', bad, final / 'bin/probe'], check=True)
    r = subprocess.run([sys.executable, '-B', audit, str(final), json.dumps(cfg), common],
                       env=env, capture_output=True)
    assert r.returncode, bad
print('frontend-and-complete-suffix-contracts')

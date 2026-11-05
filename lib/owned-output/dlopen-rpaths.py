"""Opt-in transitive RPATH for consumers whose libc dlopens an unwinder.

Use the existing provider/shrink algorithm first. RUNPATH is not inherited by
libc's dlopen call, so explicit dlopen directories also need the RPATH tag.
"""
from pathlib import Path
import subprocess
import sys

subprocess.run([sys.executable, '-B', sys.argv[4],
                *sys.argv[1:4]], check=True)
sys.path.insert(0, sys.argv[3])
from common import elf, files, invocation, preserving_times, tool

root, config = invocation()
if not config['dlopenDirectories']:
    raise ValueError('transitive RPATH requires explicit dlopen directories')
for path in files(root, config['paths']):
    classification = elf(path, config['readelf'])
    if classification is None or not classification[0]:
        continue
    def configure():
        value = tool(config['patchelf'], '--print-rpath', path).rstrip('\n')
        for directory in config['dlopenDirectories']:
            if directory not in value.split(':'):
                raise ValueError('dlopen directory lost during shrinking: ' + directory)
        tool(config['patchelf'], '--force-rpath', '--set-rpath', value, path)
    preserving_times(path, configure)

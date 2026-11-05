"""Opt-in transitive RPATH for consumers whose libc dlopens an unwinder.

Run the provider/shrink algorithm and reuse its selector and normalized paths.
RUNPATH is not inherited by libc's dlopen call, so preserve the RPATH tag too.
"""
import runpy
import sys

original = runpy.run_path(sys.argv[4])
root, config = original['root'], original['config']
if not original['preserve']:
    raise ValueError('transitive RPATH requires explicit dlopen directories')
for path in original['files'](root, config['paths']):
    classification = original['runtime_elf'](path)
    if classification is None or not classification[0]:
        continue
    def configure():
        value = original['tool'](config['patchelf'], '--print-rpath', path).rstrip('\n')
        for directory in original['preserve']:
            if directory not in value.split(':'):
                raise ValueError('dlopen directory lost during shrinking: ' + directory)
        original['tool'](config['patchelf'], '--force-rpath', '--set-rpath', value, path)
    original['preserving_times'](path, configure)

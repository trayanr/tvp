import sys
sys.path.insert(0, sys.argv[4])
"""Set only PT_INTERP on explicitly selected native runtime ELF; preflight all files."""
from shared import executable, files, invocation, selectors, tool
from common import elf, preserving_times

root, config = invocation()
loader = executable(config['loader'])
operations = []
for path in files(root, selectors(config)):
    if path.stat().st_nlink != 1:
        raise ValueError(f'shared interpreter target: {path}')
    kind = elf(path, config['readelf'])
    if kind is not None and kind[1]:
        operations.append(path)
for path in operations:
    preserving_times(path, lambda: tool(config['patchelf'], '--set-interpreter', loader, path))
    if tool(config['patchelf'], '--print-interpreter', path).rstrip('\n') != loader:
        raise ValueError(f'interpreter verification failed: {path}')

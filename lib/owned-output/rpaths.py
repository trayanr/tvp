import sys
sys.path.insert(0, sys.argv[3])
from common import elf, files, invocation, preserving_times, store_directories, tool

root, config = invocation()
providers = store_directories(config['libraries'])
preserve = store_directories(config['dlopenDirectories'])
base = config['baseDirectories']
for path in files(root, config['paths']):
    classification = elf(path, config['readelf'])
    if classification is None or not classification[0]:
        continue

    def configure():
        # Prune unused base paths before applying authoritative providers.
        tool(config['patchelf'], '--shrink-rpath', path)
        before = tool(config['patchelf'], '--print-rpath', path).rstrip('\n')
        # Selected providers precede retained base/self paths. Drop every other
        # non-base path, including providers used while constructing artifacts.
        retained = providers.copy()
        for directory in before.split(':') if before else []:
            if (directory in base or directory == str(root) or directory.startswith(str(root) + '/')):
                if directory not in retained:
                    retained.append(directory)
        for directory in preserve:
            if directory not in retained:
                retained.append(directory)
        value = ':'.join(retained)
        if value != before:
            tool(config['patchelf'], '--set-rpath', value, path)
    preserving_times(path, configure)

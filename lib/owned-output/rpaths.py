import os
import struct
import sys
sys.path.insert(0, sys.argv[3])
from common import elf, files, invocation, preserving_times, store_directories, tool

root, config = invocation()
providers = store_directories(config['libraries'])
preserve = store_directories(config['dlopenDirectories'])
base = config['baseDirectories']
kinds = config['elfKinds']
if kinds is not None and kinds != ['runtime']:
    raise ValueError('RPATH selection supports only elfKinds = [ "runtime" ]')
artifact = os.environ.get('TVP_ARTIFACT_ROOT')


def runtime_elf(path):
    # Match the existing selector: validate excluded ET_REL files, but never
    # pass them to an operation that requires program headers.
    if kinds is not None:
        with path.open('rb') as stream:
            header = stream.read(64)
        if header.startswith(b'\x7fELF') and len(header) >= 18 and struct.unpack_from('<H', header, 16)[0] == 1:
            if len(header) != 64 or header[4:7] != b'\x02\x01\x01':
                raise ValueError(f'expected native ELF64 little-endian: {path}')
            _, machine, version = struct.unpack_from('<HHI', header, 16)
            ehsize = struct.unpack_from('<H', header, 52)[0]
            shoff = struct.unpack_from('<Q', header, 40)[0]
            shsize, shnum = struct.unpack_from('<HH', header, 58)
            size = path.stat().st_size
            if (machine != 62 or version != 1 or ehsize != 64 or shsize != 64
                    or not shnum or shoff < 64 or shoff + shsize * shnum > size):
                raise ValueError(f'invalid/unsupported native relocatable ELF: {path}')
            with path.open('rb') as stream:
                stream.seek(shoff)
                for _ in range(shnum):
                    section = struct.unpack('<IIQQQQIIQQ', stream.read(shsize))
                    if section[1] != 8 and section[4] + section[5] > size:
                        raise ValueError(f'truncated native relocatable ELF section: {path}')
            tool(config['readelf'], '--wide', '--file-header', '--section-headers', path)
            return None
    return elf(path, config['readelf'])


for path in files(root, config['paths']):
    classification = runtime_elf(path)
    if classification is None or not classification[0]:
        continue

    def configure():
        original = tool(config['patchelf'], '--print-rpath', path).rstrip('\n')
        # A copied package must resolve its own libraries under the final output,
        # before shrinking tests which directories satisfy DT_NEEDED.
        rebased = []
        for directory in original.split(':') if original else []:
            if artifact and (directory == artifact or directory.startswith(artifact + '/')):
                directory = str(root) + directory[len(artifact):]
            rebased.append(directory)
        value = ':'.join(rebased)
        if value != original:
            tool(config['patchelf'], '--set-rpath', value, path)
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

"""Tiny synthetic source-slot controls. No compiler or payload execution."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import struct
import sys


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def native(payload, flags=2, section=b'.rodata'):
    names = b'\0.shstrtab\0' + section + b'\0'
    offset = 64 + len(names)
    shoff = (offset + len(payload) + 7) // 8 * 8
    header = bytearray(64)
    header[:16] = b'\x7fELF\x02\x01\x01' + b'\0' * 9
    struct.pack_into('<HHIQQQIHHHHHH', header, 16,
                     3, 62, 1, 0, 0, shoff, 0, 64, 0, 0, 64, 3, 1)
    data = bytes(header) + names + payload
    data += b'\0' * (shoff - len(data))
    return data + bytes(64) + struct.pack('<IIQQQQIIQQ', 1, 3, 0, 0, 64, len(names), 0, 0, 1, 0) + struct.pack(
        '<IIQQQQIIQQ', 11, 1, flags, 0, offset, len(payload), 0, 0, 1, 0)


def main(work, readelf, patchelf):
    root = Path(work)
    root.mkdir()
    module = load('fontconfig_profile', Path(__file__).parent / '../profile-relocate.py')
    elf = load('fontconfig_profile_elf', Path(__file__).parent / '../../libxml2/ordinary/elf.py')
    outputs = {}
    for case in ['positive', 'xml', 'xml-unknown-dir', 'xml-unknown-path', 'xml-attribute', 'xml-other-role', 'xml-writable', 'xml-code', 'writable', 'code', 'unknown-path', 'structured', 'external-link', 'external-hardlink', 'unequal']:
        final = root / case / 'final'; final.mkdir(parents=True)
        old = ('/nix/store/' + 'a' * 32 + '-' + 'x' * (len(str(final)) - 44)).encode()
        assert len(old) == len(str(final))
        (final / 'lib').mkdir()
        path = final / 'lib/libfontconfig.so.1.16.3'
        if case == 'xml-other-role':
            path = final / 'bin/fc-profile-probe'; path.parent.mkdir()
        constants = [old + suffix for suffix in [b'/etc/fonts', b'/etc/fonts/conf.d', b'/share/fontconfig/conf.avail', b'/var/cache/fontconfig']]
        payload = b'\0'.join(constants) + b'\0foreign-provider\0'
        if case.startswith('xml'):
            xml = (b'<fontconfig>\t<dir>/usr/share/fonts</dir>\n'
                   b'\t<dir>/usr/local/share/fonts</dir>\n'
                   b'  <dir prefix="xdg">fonts</dir>'
                   b'  <cachedir>' + old + b'/var/cache/fontconfig</cachedir>'
                   b'  <cachedir prefix="xdg">fontconfig</cachedir>'
                   b'  <include ignore_missing="yes">' + old + b'/etc/fonts/conf.d</include>'
                   b'  <include ignore_missing="yes" prefix="xdg">fontconfig/conf.d</include>'
                   b'  <include ignore_missing="yes" prefix="xdg">fontconfig/fonts.conf</include>'
                   b'</fontconfig>')
            if case == 'xml-unknown-dir': xml = xml.replace(b'/usr/local/share/fonts', b'/unowned/fonts')
            if case == 'xml-unknown-path': xml = xml.replace(b'/etc/fonts/conf.d', b'/etc/fonts/unknown')
            if case == 'xml-attribute': xml = xml.replace(b'<fontconfig>', b'<fontconfig unknown="yes">')
            payload += xml + b'\0'
        data = native(payload, flags=3 if case in ('writable', 'xml-writable') else 2, section=b'.text' if case in ('code', 'xml-code') else b'.rodata')
        if case == 'unknown-path': data = native(old + b'/etc/unowned\0')
        if case == 'structured': data = b'structured\0' + old
        path.write_bytes(data)
        metadata = final / 'lib/pkgconfig/fontconfig.pc'; metadata.parent.mkdir(); metadata.write_bytes(b'prefix=' + old + b'\n')
        if case == 'external-link': (final / 'lib/external').symlink_to('/unowned')
        if case == 'external-hardlink': os.link(path, final.parent / 'external')
        snapshot = {p: p.read_bytes() for p in [path, metadata]}
        try:
            module.finalize(final, old.decode() + ('long' if case == 'unequal' else ''), readelf, patchelf, elf)
        except ValueError:
            assert case not in ('positive', 'xml')
            assert snapshot == {p: p.read_bytes() for p in snapshot}
        else:
            assert case in ('positive', 'xml')
            assert path.read_bytes() == data.replace(old, str(final).encode())
            assert len(path.read_bytes()) == len(data)
            assert b'foreign-provider' in path.read_bytes()
            assert old not in metadata.read_bytes()
        outputs[case] = True
    shutil.rmtree(root)
    return outputs


if __name__ == '__main__':
    print(json.dumps(main(*sys.argv[1:]), sort_keys=True))

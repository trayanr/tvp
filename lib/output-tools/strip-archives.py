"""GNU normal ar containing only native, non-LTO ELF64 x86_64 ET_REL objects.

Short names, GNU // long names and the optional GNU 32-bit / symbol index are
supported. Thin, BSD/64-bit-index, empty, malformed, foreign and LTO archives
fail. Ordinary unrelated files are skipped; .a suffixes claim archive format.
The declared strip -S -p then ranlib -D are ONE checked, per-archive operation.
Only after both succeed are bytes copied into the installed inode. Existing
hardlinks, mode, atime and mtime survive. No arbitrary strip flags, cross tools,
plugin lookup or index preservation by accident is promised.
"""

import struct

from shared import executable, files, invocation, restore, selectors, tool, transformed


def reject(path, reason):
    raise ValueError(f"unsupported/malformed native archive {path}: {reason}")


def object_member(data, path):
    if (len(data) < 64 or data[:7] != b"\x7fELF\x02\x01\x01"
            or data[7] not in (0, 3) or data[8] != 0):
        reject(path, "expected ELF64 little-endian object member")
    kind, machine, version = struct.unpack_from("<HHI", data, 16)
    shoff = struct.unpack_from("<Q", data, 40)[0]
    ehsize, phsize, phnum, shsize, shnum, shstr = struct.unpack_from("<HHHHHH", data, 52)
    if (kind != 1 or machine != 62 or version != 1 or ehsize != 64 or phnum
            or shsize != 64 or not shnum or not 0 < shstr < shnum
            or shoff < 64 or shoff + shsize * shnum > len(data)):
        reject(path, "expected native ET_REL with ordinary section headers")
    sections = [struct.unpack_from("<IIQQQQIIQQ", data, shoff + 64 * i) for i in range(shnum)]
    strings = sections[shstr]
    if strings[1] != 3:
        reject(path, "invalid section-name table")
    for section in sections:
        if section[1] != 8 and section[4] + section[5] > len(data):
            reject(path, "truncated section")
    names = data[strings[4]:strings[4] + strings[5]]
    for section in sections:
        offset = section[0]
        end = names.find(b"\0", offset)
        if offset >= len(names) or end < 0:
            reject(path, "invalid section name")
        name = names[offset:end]
        if name.startswith((b".gnu.lto_", b".llvm", b".llvmbc")):
            reject(path, "LTO/LLVM members are outside this native contract")


def archive(path):
    data = path.read_bytes()
    if data.startswith(b"!<thin>\n"):
        reject(path, "thin archives are not supported")
    if not data.startswith(b"!<arch>\n"):
        reject(path, "expected normal GNU ar magic")
    offset, objects, longnames = 8, 0, None
    members, index_offsets = set(), None
    while offset < len(data):
        header = data[offset:offset + 60]
        if len(header) != 60 or header[58:] != b"`\n":
            reject(path, "invalid member header")
        name = header[:16].rstrip(b" ")
        for start, end, base in ((16, 28, 10), (28, 34, 10), (34, 40, 10),
                                 (40, 48, 8), (48, 58, 10)):
            number = header[start:end].strip()
            if name == b"//" and start != 48 and not number:
                continue  # GNU's name table has blank metadata fields.
            if not number or any(c not in (b"01234567" if base == 8 else b"0123456789") for c in number):
                reject(path, "invalid numeric member field")
        length = int(header[48:58])
        begin = offset + 60
        end = begin + length
        if end > len(data) or (length % 2 and data[end:end + 1] != b"\n"):
            reject(path, "truncated member or invalid padding")
        member = data[begin:end]
        if name == b"//":
            if longnames is not None:
                reject(path, "duplicate GNU name table")
            longnames = member
        elif name == b"/":
            # GNU 32-bit symbol index: offsets and terminated symbol names.
            if len(member) < 4 or index_offsets is not None:
                reject(path, "truncated symbol index")
            count = struct.unpack_from(">I", member)[0]
            if 4 + count * 4 > len(member):
                reject(path, "invalid symbol index")
            index_offsets = struct.unpack_from(f">{count}I", member, 4)
            symbols = member[4 + count * 4:]
            for _ in range(count):
                end_name = symbols.find(b"\0")
                if end_name <= 0:
                    reject(path, "invalid symbol index name")
                symbols = symbols[end_name + 1:]
            if symbols not in (b"", b"\0"):
                reject(path, "invalid symbol index padding")
        else:
            if name.startswith(b"/"):
                index = name[1:]
                if not index.isdigit() or longnames is None:
                    reject(path, "unsupported archive name/index format")
                index = int(index)
                if (index >= len(longnames) or (index and longnames[index - 1:index] != b"\n")
                        or longnames.find(b"/\n", index) < 0):
                    reject(path, "invalid GNU long member name")
            elif not name or not name.endswith(b"/") or name.startswith(b"#1/"):
                reject(path, "expected GNU short or long member name")
            object_member(member, path)
            objects += 1
            members.add(offset)
        offset = end + length % 2
    if not objects:
        reject(path, "expected at least one native object member")
    if index_offsets is not None and any(i not in members for i in index_offsets):
        reject(path, "symbol index does not point to object headers")


root, config = invocation()
paths = selectors(config)
strip, ranlib, readelf = (executable(config[key]) for key in ("strip", "ranlib", "readelf"))
for path in files(root, paths):
    # Nonarchives in directory scopes are deliberately skipped. A .a suffix is
    # an explicit archive claim; malformed/thin content must not disappear.
    info = path.stat()
    try:
        with path.open("rb") as stream:
            magic = stream.read(8)
        if path.suffix != ".a" and magic not in (b"!<arch>\n", b"!<thin>\n"):
            continue
        archive(path)
        tool(readelf, "--wide", "--file-header", "--section-headers", "--symbols", path)

        def operation(staged):
            tool(strip, "-S", "-p", staged)
            tool(ranlib, "-D", staged)
            archive(staged)
            tool(readelf, "--wide", "--file-header", "--section-headers", "--symbols", staged)

        transformed(path, operation)
    finally:
        restore(path, info)

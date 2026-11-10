"""Rebind copied glibc scripts; ELF/symlinks stay byte-identical.

Private-tree preflight rejects hardlinks and symlinked parents before writes.
The configured Perl fallback is replaced together with the shebang. Shell tools
receive an explicit auxiliary PATH, so ldd/xtrace/sotruss do not depend on callers.
"""
import os
from pathlib import Path
import sys

from prepare import private_files, replace


def main():
    root, bash, perl, old_perl, tool_path = sys.argv[1:]
    for binary in (bash, perl):
        if (not os.path.isabs(binary) or any(c.isspace() for c in binary)
                or not os.access(binary, os.X_OK)):
            raise ValueError('expected explicit executable interpreter')
    if any(c in tool_path for c in "'\n\0") or not all(os.path.isabs(p) for p in tool_path.split(':')):
        raise ValueError('expected explicit auxiliary tool PATH')
    files = private_files(root)
    pending = []
    for path in files:
        if not path.stat().st_mode & 0o111:
            continue
        with path.open('rb') as stream:
            head = stream.read(256)
        if not head.startswith(b'#!'):
            continue
        data = path.read_bytes()
        line, newline, body = data.partition(b'\n')
        words = line[2:].strip().split()
        if not newline or len(words) != 1:
            raise ValueError('unsupported script directive: ' + str(path))
        name = Path(os.fsdecode(words[0])).name
        if name == 'perl':
            target = perl
            if path.name == 'mtrace':
                old = ('eval "exec ' + old_perl + ' -S $0 $@"').encode()
                if body.count(old) != 1:
                    raise ValueError('expected configured mtrace Perl fallback')
                body = body.replace(old, ('eval "exec ' + perl + ' -S $0 $@"').encode())
        elif name in ('sh', 'bash'):
            target = bash
            marker = b'# TVP glibc auxiliary PATH\n'
            if body.startswith(marker):
                assignment, separator, rest = body[len(marker):].partition(b'\n')
                if not separator or not assignment.startswith(b"export PATH='") or not assignment.endswith(b"'"):
                    raise ValueError('malformed previous auxiliary PATH')
                body = rest
            body = marker + ("export PATH='" + tool_path + "'\n").encode() + body
        else:
            raise ValueError('unexpected glibc script interpreter: ' + name)
        directive = b'#!' + target.encode()
        if len(directive) > 255:
            raise ValueError('interpreter exceeds native shebang limit')
        pending.append((path, directive + b'\n' + body))
    for path, data in pending:
        replace(path, data)


if __name__ == '__main__':
    main()

"""Explicit native Linux interpreter replacement, with no PATH lookup or shell eval.

Match executable scripts by interpreter basename. Keep direct optional-argument
bytes verbatim; convert plain env NAME and env -S NAME only. Argument-bearing -S,
options, assignments and quoting on matching env directives fail. This deliberately
does not parse the GNU env language. Native Linux lines are limited to 255 bytes
before the newline. Body bytes, inode, mode, atime and mtime are retained.
"""

import os
import re

from shared import executable, files, invocation, replace_contents, restore, selected, selectors


def replacement(line, names, target):
    if not line.startswith(b"#!"):
        return None
    directive = line[2:].lstrip(b" \t")
    match = re.fullmatch(rb"([^ \t\r\n\0]+)([ \t].*)?", directive)
    # Look for declared names even in unsupported env syntax; never silently
    # discard an option, assignment, quoting rule or argument while rewriting.
    mentioned = any(re.search(rb"(?<![\w.+-])" + re.escape(n) + rb"(?![\w.+-])", directive)
                    for n in names)
    if match is None:
        if mentioned:
            raise ValueError("unsupported matching shebang syntax")
        return None
    original, tail = match.group(1), match.group(2) or b""
    name = original.rsplit(b"/", 1)[-1]
    if name == b"env":
        if not mentioned:
            return None
        words = tail.split()
        if words and words[0] == b"-S":
            words = words[1:]
        # An unrelated simple interpreter stays unrelated even if one of its
        # arguments mentions a selected name. Quoted matching names still fail.
        if (words and not words[0].startswith(b"-") and b"=" not in words[0]
                and words[0].strip(b"\"'") not in names):
            return None
        if len(words) != 1 or words[0] not in names:
            raise ValueError("unsupported matching env shebang (options, assignments or arguments)")
        tail = b""
    elif name not in names:
        return None
    elif not original.startswith(b"/"):
        raise ValueError("unsupported matching direct shebang: expected absolute interpreter")
    if b"\0" in line or b"\r" in line or len(line) > 255:
        raise ValueError("unsupported matching shebang syntax/length (native limit 255 bytes)")
    result = b"#!" + target + tail
    if len(result) > 255:
        raise ValueError("replacement shebang exceeds native limit of 255 bytes")
    return result


root, config = invocation()
paths = selectors(config)
names = config["names"]
if (not isinstance(names, list) or not names
        or not all(isinstance(n, str) and re.fullmatch(r"[A-Za-z0-9_][A-Za-z0-9_.+-]*", n) for n in names)
        or "env" in names):
    raise ValueError("names must be nonempty interpreter basenames (excluding env)")
external, own = config["interpreter"], config["selfInterpreter"]
if (external is None) == (own is None):
    raise ValueError("select exactly one interpreter or selfInterpreter")
if own is not None:
    target = executable(str(selected(root, own)))
else:
    target = executable(external)
    # Absolute spelling is not a way to bypass owned-output symlink validation.
    if target.startswith(str(root) + "/"):
        selected(root, target[len(str(root)) + 1:])
names = [n.encode("ascii") for n in names]
for path in files(root, paths):
    info = path.stat()
    if not info.st_mode & 0o111:
        continue
    try:
        with path.open("rb") as stream:
            prefix = stream.read(257)
            line = prefix.split(b"\n", 1)[0]
            rewritten = replacement(line, names, os.fsencode(target))
            if rewritten is None or rewritten == line:
                continue
            stream.seek(0)
            contents = stream.read()
        _, newline, body = contents.partition(b"\n")
        replace_contents(path, rewritten + newline + body)
    finally:
        restore(path, info)

"""Canonicalize Automake 1.11.2's configured tree for checkpoint replay."""

import json
import runpy
import stat
import sys


CONFIGURED_FILES = (
    "Makefile",
    "doc/Makefile",
    "lib/Automake/Makefile",
    "lib/Automake/tests/Makefile",
    "lib/Makefile",
    "lib/am/Makefile",
    "m4/Makefile",
    "tests/Makefile",
    "tests/defs",
    "tests/aclocal-1.11",
    "tests/automake-1.11",
)
GENERATED_FILES = ("aclocal", "automake", "lib/Automake/Config.pm")
NANOSECONDS = 1_000_000_000


def normalize(checkpoint):
    layout_file = checkpoint / "layout.json"
    layout = json.loads(layout_file.read_text())
    if layout["schema"] != 1:
        return "unexpected checkpoint schema"
    epoch = int(layout["sourceDateEpoch"]) * NANOSECONDS
    source = checkpoint / "source"
    timestamps = layout["timestamps"]
    # config.status appends configure diagnostics to config.log if it runs.
    # No build target needs the initial log, which records the builder's kernel.
    log = source / "config.log"
    if "config.log" not in timestamps or not stat.S_ISREG(log.lstat().st_mode):
        return "expected a regular configure log"

    # The distributed sources retain their archive ordering. The Makefiles
    # depend on config.status, and generated tools depend on their Makefiles.
    phases = (("config.status",), CONFIGURED_FILES, GENERATED_FILES)
    normalized = {}
    for phase, names in enumerate(phases, start=1):
        for name in names:
            if name not in timestamps or not stat.S_ISREG((source / name).lstat().st_mode):
                return f"missing regular build target: {name}"
            normalized[name] = epoch + phase * NANOSECONDS

    for name, timestamp in timestamps.items():
        if name == "config.log" or name in normalized:
            continue
        if stat.S_ISREG((source / name).lstat().st_mode):
            # Custom step edits can add files with new prerequisite ordering.
            # Preserve the original checkpoint when that ordering is unknown.
            if timestamp > epoch:
                return f"unclassified late file: {name}"
            normalized[name] = timestamp
        else:
            normalized[name] = epoch

    log.unlink()
    layout["timestamps"] = normalized
    layout_file.write_text(json.dumps(layout, sort_keys=True) + "\n")
    return None


if __name__ == "__main__":
    implementation, mode, workspace, destination = sys.argv[1:]
    writer = runpy.run_path(implementation)
    checkpoint = writer["absolute"](destination)
    writer["save"](writer["absolute"](workspace), checkpoint)
    reason = "custom patches or configure flags" if mode == "preserve" else normalize(checkpoint)
    if reason is not None:
        print(f"Automake: kept original checkpoint timestamps ({reason})", file=sys.stderr)

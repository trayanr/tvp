"""Focused controls for production/test-source isolation; no package rebuild."""
import os
from pathlib import Path
import subprocess
import sys

production, attr_acl_upstream, libxcrypt_upstream, common, shell, perl = sys.argv[1:]
base = Path.cwd()
for family in ("attr", "acl", "libxcrypt"):
    upstream = libxcrypt_upstream if family == "libxcrypt" else attr_acl_upstream
    if family in {"attr", "acl"}:
        # Configure creates include/<family> aliases outside the selected test tree.
        # U must leave those production aliases alone while binding its own frontend.
        root = base / (family + "-restored-alias")
        (root / "include").mkdir(parents=True)
        (root / "include" / family).symlink_to(".")
        (root / "test").mkdir()
        target = root / "test/frontend"
        target.write_text("#!/bin/sh\n:\n")
        result = subprocess.run([sys.executable,"-B",upstream,family,shell,perl,common],cwd=root,capture_output=True)
        assert result.returncode == 0, (root,result.stdout,result.stderr)
        assert target.read_bytes().startswith(("#!" + shell + "\n").encode())
        assert (root / "include" / family).is_symlink()
        print("PASS",root.name,file=sys.stderr)
    for mode in ("production", "upstream"):
        for bad in ("unknown", "nul", "hardlink", "symlink"):
            root = base / (family + "-" + mode + "-" + bad)
            root.mkdir()
            (root / "configure").write_text("#!/bin/sh\n/usr/bin/file\n")
            (root / "build-aux").mkdir()
            (root / "build-aux/ltmain.sh").write_text("#!/bin/sh\neval sys_lib_search_path=foo\n")
            (root / "test").mkdir()
            target = root / "build-aux/test-driver"
            target.write_bytes(b"#!/usr/bin/python3\npass\n" if bad == "unknown" else b"#!/bin/sh\n: \0\n" if bad == "nul" else b"#!/bin/sh\n:\n")
            outside = base / (root.name + "-outside")
            outside.write_text("unchanged")
            if bad == "hardlink": target.unlink(); os.link(outside, target)
            if bad == "symlink": target.unlink(); target.symlink_to(outside)
            before = {p.relative_to(root).as_posix(): p.read_bytes() for p in root.rglob("*") if p.is_file() and not p.is_symlink()}
            helper = production if mode == "production" else upstream
            result = subprocess.run([sys.executable,"-B",helper,family,shell,perl,common],cwd=root,capture_output=True)
            # A ignores test contents; confinement still rejects aliases to
            # outside paths and hardlinks, even when no write was planned.
            expected_success = mode == "production" and bad in {"unknown", "nul"}
            assert (result.returncode == 0) == expected_success, (root,result.stdout,result.stderr)
            if not expected_success:
                after = {p.relative_to(root).as_posix(): p.read_bytes() for p in root.rglob("*") if p.is_file() and not p.is_symlink()}
                assert before == after, root
            assert outside.read_text() == "unchanged"
            print("PASS",root.name,file=sys.stderr)

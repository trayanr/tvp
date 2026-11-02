"""Fresh sandbox controls for the explicitly selected reusable output operations."""

import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import tempfile
import unittest

SCRIPTS, COMMON, BINUTILS, BASH, PYTHON, CC = sys.argv[1:7]
del sys.argv[1:7]
STAMP = 1700000000123456789


def command(*args, **kwargs):
    return subprocess.run(list(map(str, args)), check=True, stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE, **kwargs).stdout


class Helpers(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(dir=os.environ["TMPDIR"])
        self.addCleanup(self.temp.cleanup)
        self.work = Path(self.temp.name)
        self.root = self.work / "out"
        (self.root / "lib").mkdir(parents=True)
        (self.root / "bin").mkdir()
        self.config = {"paths": ["lib"], "strip": f"{BINUTILS}/bin/strip",
                       "ranlib": f"{BINUTILS}/bin/ranlib", "readelf": f"{BINUTILS}/bin/readelf",
                       "names": ["bash", "python3"], "interpreter": BASH, "selfInterpreter": None}

    def step(self, name, *, fail=None, **options):
        result = subprocess.run([sys.executable, "-B", f"{SCRIPTS}/{name}.py", str(self.root),
                                 json.dumps(self.config | options), COMMON],
                                env={"TMPDIR": str(self.work)}, cwd=self.work,
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if fail is None:
            self.assertEqual(result.returncode, 0, result.stderr.decode())
        else:
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(fail.encode(), result.stderr)
        return result

    def wrapper(self, name, body):
        path = self.work / name
        path.write_text(f"#!{sys.executable}\n" + body)
        path.chmod(0o755)
        return str(path)

    def archive(self, name="probe.a", *, thin=False, lto=False, native_metadata=False):
        objects = []
        for local, code in (("first long member name", "int first(void) { return 19; }\n"),
                            ("second", "int second(void) { return 23; }\n")):
            source = self.work / f"{local}.c"
            source.write_text(code)
            obj = source.with_suffix(".o")
            command(CC, "-g", *(["-flto"] if lto else []), "-c", source, "-o", obj)
            if native_metadata and not objects:
                metadata = self.work / "metadata"
                metadata.write_bytes(b"\0")
                command(f"{BINUTILS}/bin/objcopy",
                        "--add-section", f".llvm_addrsig={metadata}",
                        "--add-section", f".llvmcmd={metadata}", obj)
            objects.append(obj)
        path = self.root / "lib" / name
        command(f"{BINUTILS}/bin/ar", "rcsT" if thin else "rcsD", path, *objects)
        return path

    def script(self, name, directive, body=b"printf 'bash works\\n'\n", mode=0o751):
        path = self.root / "bin" / name
        path.write_bytes(directive + b"\n" + body)
        path.chmod(mode)
        os.utime(path, ns=(STAMP, STAMP))
        return path

    def test_archive_links_symbols_index_hardlinks_and_selected_tools(self):
        path = self.archive("-space ' and\nnewline.a")
        alias = path.with_name("alias.a")
        os.link(path, alias)
        path.chmod(0o444)
        os.utime(path, ns=(STAMP, STAMP))
        inode = path.stat().st_ino
        self.assertIn(b".debug_info", command(self.config["readelf"], "-S", path))
        os.utime(path, ns=(STAMP, STAMP))
        unrelated = self.root / "lib/text"
        unrelated.write_bytes(b"unrelated")
        log = self.work / "calls.jsonl"
        overrides = {}
        for key in ("strip", "ranlib"):
            overrides[key] = self.wrapper(f"selected-{key}", f'''import json, subprocess, sys
with open({str(log)!r}, 'a') as f: f.write(json.dumps([{key!r}, *sys.argv[1:]]) + '\\n')
subprocess.run([{self.config[key]!r}, *sys.argv[1:]], check=True)
''')
        self.step("strip-archives", paths=["lib", "lib/alias.a"], **overrides)
        self.assertEqual(path.stat().st_atime_ns, STAMP)
        self.assertNotIn(b".debug_info", command(self.config["readelf"], "-S", path))
        armap = command(f"{BINUTILS}/bin/nm", "--print-armap", path)
        self.assertIn(b"Archive index:", armap)
        self.assertIn(b"first in first long member name.o", armap)
        self.assertEqual([json.loads(s)[0] for s in log.read_text().splitlines()], ["strip", "ranlib"])
        self.assertEqual(path.stat().st_ino, inode)
        self.assertEqual(alias.stat().st_ino, inode)
        self.assertEqual(path.stat().st_mode & 0o777, 0o444)
        self.assertEqual(path.stat().st_mtime_ns, STAMP)
        self.assertEqual(unrelated.read_bytes(), b"unrelated")
        consumer = self.work / "consumer.c"
        consumer.write_text("int first(void); int second(void); int main(void) { return first()+second()!=42; }\n")
        exe = self.work / "consumer"
        command(CC, consumer, path, "-o", exe)
        command(exe, env={})

    def test_archive_tool_failures_do_not_mutate_installed_inode(self):
        path = self.archive()
        original = path.read_bytes()
        for key, status in (("strip", 23), ("ranlib", 24), ("readelf", 25)):
            self.step("strip-archives", **{key: self.wrapper(f"fail-{key}", f"raise SystemExit({status})\n")},
                      fail=f"exit status {status}")
            self.assertEqual(path.read_bytes(), original)

    def test_native_metadata_is_not_lto(self):
        path = self.archive(native_metadata=True)
        self.step("strip-archives")
        sections = command(self.config["readelf"], "-S", path)
        self.assertIn(b".llvm_addrsig", sections)
        self.assertIn(b".llvmcmd", sections)
        consumer = self.work / "consumer.c"
        consumer.write_text("int first(void); int second(void); int main(void) { return first()+second()!=42; }\n")
        exe = self.work / "consumer"
        command(CC, consumer, path, "-o", exe)
        command(exe, env={})

        obj = self.work / "first long member name.o"
        bitcode = self.work / "unsupported-bitcode"
        bitcode.write_bytes(b"unsupported bitcode")
        for section in (".llvm.lto", ".llvmbc"):
            command(f"{BINUTILS}/bin/objcopy", "--add-section", f"{section}={bitcode}", obj)
            command(f"{BINUTILS}/bin/ar", "rcsD", path, obj)
            original = path.read_bytes()
            self.step("strip-archives", fail="LTO")
            self.assertEqual(path.read_bytes(), original)
            command(f"{BINUTILS}/bin/objcopy", "--remove-section", section, obj)

    def test_archive_rejects_thin_malformed_foreign_lto_and_nonobject(self):
        path = self.archive(thin=True)
        self.step("strip-archives", fail="thin archives")
        path.unlink()
        path = self.root / "lib/bad.a"
        for data in (b"not ar", b"!<arch>\ntruncated"):
            path.write_bytes(data)
            self.step("strip-archives", fail="unsupported/malformed native archive")
        path.unlink()
        path = self.archive(lto=True)
        self.step("strip-archives", fail="LTO")
        path.unlink()
        path = self.archive()
        data = bytearray(path.read_bytes())
        index = data.index(b"\x7fELF")
        struct.pack_into("<H", data, index + 18, 183)
        path.write_bytes(data)
        self.step("strip-archives", fail="expected native ET_REL")
        path.unlink()
        text = self.work / "text"
        text.write_bytes(b"not an object")
        command(f"{BINUTILS}/bin/ar", "rcs", path, text)
        self.step("strip-archives", fail="expected ELF64")

    def test_scoped_symlinks_and_invalid_selectors(self):
        archive = self.archive()
        script = self.script("bash", b"#!/bin/bash")
        outside = self.work / "external"
        outside.mkdir()
        shutil.copyfile(archive, outside / "untouched.a")
        shutil.copyfile(script, outside / "script")
        (outside / "script").chmod(0o755)
        original = (outside / "untouched.a").read_bytes()
        (self.root / "lib/external").symlink_to(outside)
        (self.root / "bin/external").symlink_to(outside)
        (self.root / "bin/external-file").symlink_to(outside / "script")
        (self.root / "lib/link.a").symlink_to(outside / "untouched.a")
        for helper, directory in (("strip-archives", "lib"), ("shebangs", "bin")):
            self.step(helper, paths=[directory])
            link = "lib/link.a" if helper == "strip-archives" else "bin/external-file"
            for selector in (f"{directory}/external", f"{directory}/external/script", link):
                self.step(helper, paths=[selector], fail="symlink output selector")
            for selector in ("../external", "/etc", "lib/../bin", "bin//bash", "bin/./bash", "bin/\0"):
                self.step(helper, paths=[selector], fail="unsafe output selector")
            self.step(helper, paths="bin", fail="paths must be a nonempty list")
            self.step(helper, paths=["missing"], fail="No such file")
        self.assertEqual((outside / "untouched.a").read_bytes(), original)
        self.assertEqual((outside / "script").read_bytes(), script.read_bytes().replace(BASH.encode(), b"/bin/bash"))

    def test_bash_forms_body_hardlinks_metadata_and_idempotence(self):
        for name, directive in (("direct", b"#!/bin/bash -e"), ("env", b"#!/usr/bin/env bash"),
                                ("split", b"#!/usr/bin/env -S bash")):
            mode = 0o551 if name == "env" else 0o751
            path = self.script(name + " space\n'", directive, mode=mode)
            alias = path.with_name(name + "-hardlink")
            os.link(path, alias)
            inode = path.stat().st_ino
            self.step("shebangs", paths=["bin"], names=["bash"])
            self.assertEqual(path.stat().st_atime_ns, STAMP)
            self.assertEqual(command(path, env={}), b"bash works\n")
            body = path.read_bytes().split(b"\n", 1)[1]
            self.assertEqual(body, b"printf 'bash works\\n'\n")
            self.assertEqual(path.stat().st_ino, inode)
            self.assertEqual(alias.stat().st_ino, inode)
            self.assertEqual(path.stat().st_mode & 0o777, mode)
            self.assertEqual(path.stat().st_mtime_ns, STAMP)
            before = path.read_bytes()
            self.step("shebangs", paths=["bin"], names=["bash"])
            self.assertEqual(path.read_bytes(), before)

    def test_python_direct_optional_argument_and_minimal_environment(self):
        path = self.script("python", b"#!/usr/bin/python3 -I", b"import sys\nprint(sys.flags.isolated)\n")
        self.step("shebangs", paths=["bin"], interpreter=PYTHON, names=["python3"])
        self.assertEqual(path.read_bytes().splitlines()[0], b"#!" + PYTHON.encode() + b" -I")
        self.assertEqual(command(path, env={}), b"1\n")
        env = self.script("env-python", b"#!/usr/bin/env python3", b"print('python works')\n")
        self.step("shebangs", paths=["bin"], interpreter=PYTHON, names=["python3"])
        self.assertEqual(command(env, env={}), b"python works\n")

    def test_output_relative_real_interpreter(self):
        target = self.root / "bin/interpreter"
        shutil.copyfile(BASH, target)
        target.chmod(0o755)
        path = self.script("self", b"#!/usr/bin/env bash")
        self.step("shebangs", paths=["bin/self"], interpreter=None, selfInterpreter="bin/interpreter")
        self.assertEqual(command(path, env={}), b"bash works\n")
        before = path.read_bytes()
        self.step("shebangs", paths=["bin/self"], interpreter=None, selfInterpreter="bin/interpreter")
        self.assertEqual(path.read_bytes(), before)
        target.unlink()
        target.symlink_to(BASH)
        self.step("shebangs", paths=["bin/self"], interpreter=None, selfInterpreter="bin/interpreter",
                  fail="symlink output selector")
        self.step("shebangs", paths=["bin/self"], interpreter=str(target), fail="symlink output selector")

    def test_shebang_preserves_unrelated_nonexec_and_binary(self):
        fixtures = [self.script("unrelated", b"#!/bin/perl"),
                    self.script("unrelated-env", b"#!/usr/bin/env -S perl bash"),
                    self.script("unrelated-plain-env", b"#!/usr/bin/env perl bash"),
                    self.script("template", b"#!/usr/bin/env bash", mode=0o644),
                    self.script("binary", b"\x7fELF\x00\x01")]
        before = [(p.read_bytes(), p.stat().st_mode, p.stat().st_mtime_ns) for p in fixtures]
        self.step("shebangs", paths=["bin"], names=["bash"])
        self.assertEqual([(p.read_bytes(), p.stat().st_mode, p.stat().st_mtime_ns) for p in fixtures], before)

    def test_shebang_unsupported_forms_fail_without_changing_bytes(self):
        for directive in (b"#!/usr/bin/env -S bash -e", b"#!/usr/bin/env -S python3 -I -u",
                          b"#!/usr/bin/env -i bash", b"#!/usr/bin/env X=1 bash",
                          b"#!/usr/bin/env --split-string=bash", b"#!/usr/bin/env -S 'bash'",
                          b"#!/bin/bash\r", b"#!/bin/bash\0", b"#!bash", b"#!/bin/bash " + b"x"*250):
            path = self.script("bad", directive)
            original = path.read_bytes()
            self.step("shebangs", paths=["bin/bad"], fail="unsupported matching")
            self.assertEqual(path.read_bytes(), original)
        path.unlink()
        # Linux passes this entire tail as ONE argument. Keep it byte-for-byte;
        # execution would fail for Python, which is exactly the original meaning.
        path = self.script("opaque", b"#!/bin/python3 -I  -u")
        self.step("shebangs", paths=["bin/opaque"], interpreter=PYTHON)
        self.assertTrue(path.read_bytes().startswith(b"#!" + PYTHON.encode() + b" -I  -u\n"))

    def test_shebang_declaration_validation(self):
        self.script("bash", b"#!/bin/bash")
        for options, error in (({"interpreter": None}, "exactly one"),
                               ({"selfInterpreter": "bin/bash"}, "exactly one"),
                               ({"interpreter": "relative"}, "absolute executable"),
                               ({"interpreter": str(self.root / "missing")}, "expected executable"),
                               ({"interpreter": BASH + "\n"}, "absolute executable"),
                               ({"names": []}, "interpreter basenames"),
                               ({"names": ["bad/name"]}, "interpreter basenames")):
            self.step("shebangs", paths=["bin"], fail=error, **options)
        nonexec = self.script("nonexec", b"#!/bin/bash", mode=0o644)
        self.step("shebangs", paths=["bin/bash"], interpreter=str(nonexec), fail="expected executable")
        # Existing long executable target, rejected before writing an overlong line.
        directory = self.work / ("x"*100) / ("y"*100)
        directory.mkdir(parents=True)
        target = directory / ("z"*60)
        shutil.copyfile(BASH, target)
        target.chmod(0o755)
        self.step("shebangs", paths=["bin/bash"], interpreter=str(target), fail="exceeds native limit")


if __name__ == "__main__":
    unittest.main(verbosity=2)

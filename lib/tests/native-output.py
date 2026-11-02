"""Behavioral fixtures for the narrow native output helpers (no archives)."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

SCRIPTS = Path(sys.argv.pop(1))
BINUTILS, PATCHELF, CC, GMP, UNUSED = sys.argv[1:6]
del sys.argv[1:6]


def command(*args, **kwargs):
    return subprocess.run(list(map(str, args)), check=True, stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE, **kwargs).stdout


class OutputTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(dir=os.environ["TMPDIR"])
        self.addCleanup(self.temp.cleanup)
        self.work = Path(self.temp.name)
        self.root = self.work / "out"
        self.root.mkdir()
        self.config = {"paths": ["lib"], "readelf": f"{BINUTILS}/bin/readelf",
                       "strip": f"{BINUTILS}/bin/strip", "flags": ["-S", "-p"],
                       "patchelf": f"{PATCHELF}/bin/patchelf", "dlopenDirectories": []}
        (self.root / "lib").mkdir()

    def step(self, name, *, fail=None, **options):
        env = os.environ | {"NIX_BUILD_TOP": str(self.work / "earlier-build"),
                            "TMPDIR": str(self.work / "current-tmp")}
        proc = subprocess.run([sys.executable, "-B", str(SCRIPTS / f"{name}.py"),
                               str(self.root), json.dumps(self.config | options)],
                              env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if fail is None:
            self.assertEqual(proc.returncode, 0, proc.stderr.decode())
        else:
            self.assertNotEqual(proc.returncode, 0)
            self.assertIn(fail.encode(), proc.stderr)
        return proc

    def shared(self, name="probe.so", rpath=None):
        source = self.work / "probe.c"
        source.write_text('const char *assertion_file = "/build/source/assert.c";\n'
                          'int exported(void) { return 42; }\n')
        path = self.root / "lib" / name
        command(CC, "-g", "-shared", "-fPIC", source, "-o", path,
                *([f"-Wl,-rpath,{rpath}"] if rpath is not None else []))
        return path

    def wrapper(self, name, body):
        path = self.work / name
        # The selected interpreter, no ambient /usr/bin/env or shell lookup.
        path.write_text(f"#!{sys.executable}\n" + body)
        path.chmod(0o755)
        return str(path)

    def test_strip_hardlinks_odd_names_and_external_symlinks(self):
        path = self.shared("-space ' and\nnewline.so")
        link = path.with_name("hardlink.so")
        os.link(path, link)
        path.chmod(0o751)
        os.utime(path, ns=(1700000000000000000, 1700000000000000000))
        outside = self.work / "outside"
        outside.mkdir()
        external = outside / "untouched.so"
        shutil.copyfile(path, external)
        original = external.read_bytes()
        (self.root / "lib" / "external").symlink_to(outside)
        (self.root / "lib" / "external-file").symlink_to(external)
        log = self.work / "strip.jsonl"
        wrapper = self.wrapper("selected-strip", f'''import json, subprocess, sys
with open({str(log)!r}, 'a') as stream: stream.write(json.dumps(sys.argv[1:]) + '\\n')
subprocess.run([{self.config['strip']!r}, *sys.argv[1:]], check=True)
''')
        self.assertIn(b".debug_info", command(self.config["readelf"], "-S", path))
        self.step("strip", strip=wrapper, paths=["lib", "lib/hardlink.so"])
        calls = [json.loads(line) for line in log.read_text().splitlines()]
        self.assertEqual(len(calls), 1)
        self.assertEqual(calls[0][0:3], ["-S", "-p", "--"])
        self.assertNotIn(b".debug_info", command(self.config["readelf"], "-S", path))
        self.assertEqual(path.stat().st_ino, link.stat().st_ino)
        self.assertEqual(path.stat().st_mode & 0o777, 0o751)
        self.assertEqual(path.stat().st_mtime_ns, 1700000000000000000)
        self.assertEqual(external.read_bytes(), original)
        self.assertIn(b"exported", command(f"{BINUTILS}/bin/nm", "-D", path))
        command(sys.executable, "-c", "import ctypes,sys; "
                "assert ctypes.CDLL(sys.argv[1]).exported() == 42", path)
        self.step("strip", paths=["lib/external/untouched.so"], fail="symlink output selector")
        self.step("strip", paths=["lib/external-file"], fail="symlink output selector")
        self.step("strip", paths=["lib/../lib/hardlink.so"], fail="unsafe output selector")
        self.step("strip", paths=[str(path)], fail="unsafe output selector")

    def test_real_tool_and_malformed_elf_failures(self):
        self.shared()
        self.step("strip", strip=self.wrapper("fail-strip", "raise SystemExit(23)\n"),
                  fail="exit status 23")
        self.step("rpaths", patchelf=self.wrapper("fail-patchelf", "raise SystemExit(24)\n"),
                  fail="exit status 24")
        self.step("strip", readelf=self.wrapper("fail-readelf", "raise SystemExit(25)\n"),
                  fail="exit status 25")
        malformed = self.root / "lib" / "malformed"
        malformed.write_bytes(b"\x7fELF\x02\x01\x01")
        self.step("strip", paths=["lib/malformed"], fail="expected native ELF64")
        self.step("rpaths", paths=["lib/malformed"], fail="expected native ELF64")

    def test_static_elf_and_unsupported_text_are_not_dynamic(self):
        source = self.work / "static.s"
        source.write_text(".global _start\n_start: mov $60,%rax; xor %rdi,%rdi; syscall\n")
        obj = self.work / "static.o"
        command(f"{BINUTILS}/bin/as", source, "-o", obj)
        command(f"{BINUTILS}/bin/ld", "-static", obj, "-o", self.root / "lib/static")
        (self.root / "lib/text").write_bytes(b"non-ELF, not an installed script")
        fail = self.wrapper("must-not-run", "raise SystemExit(26)\n")
        self.step("rpaths", patchelf=fail)
        self.step("check-paths", patchelf=fail)
        command(self.root / "lib/static")

    def test_scoped_shared_libtool_metadata(self):
        contents = (b"# probe.la - a libtool library file\n# Generated by libtool\n# preserve this exactly\n"
                    b"old_library=''\ndependency_libs=' -L/tmp/not-executed -lgmp'\n"
                    b"inert='$(touch should-not-exist)'\n")
        shared = self.root / "lib/shared.la"
        shared.write_bytes(contents)
        shared.chmod(0o751)
        os.utime(shared, ns=(1700000000000000000, 1700000000000000000))
        static = self.root / "lib/static.la"
        static.write_bytes(contents.replace(b"old_library=''", b"old_library='libprobe.a'"))
        unrelated = self.root / "lib/unrelated.la"
        unrelated.write_bytes(contents.replace(b"# Generated by libtool", b"# ordinary text"))
        self.step("libtool")
        self.assertEqual(shared.read_bytes(), contents.replace(
            b"dependency_libs=' -L/tmp/not-executed -lgmp'", b"dependency_libs='' #pruned"))
        self.assertEqual(shared.stat().st_mode & 0o777, 0o751)
        self.assertEqual(shared.stat().st_mtime_ns, 1700000000000000000)
        self.assertIn(b"dependency_libs=' -L/tmp/not-executed -lgmp'", static.read_bytes())
        self.assertEqual(unrelated.read_bytes(), contents.replace(
            b"# Generated by libtool", b"# ordinary text"))
        self.assertFalse((self.work / "should-not-exist").exists())

    def test_exact_development_bytes_and_symlink_boundary(self):
        self.step("development", libraries=[GMP])
        path = self.root / "nix-support/propagated-build-inputs"
        self.assertEqual(path.read_bytes(), (GMP + " ").encode())
        path.unlink()
        outside = self.work / "metadata"
        outside.write_bytes(b"untouched")
        path.symlink_to(outside)
        self.step("development", libraries=[GMP], fail="symlink output selector")
        self.assertEqual(outside.read_bytes(), b"untouched")
        path.unlink()
        path.parent.rmdir()
        path.parent.symlink_to(self.work)
        self.step("development", libraries=[GMP], fail="symlink output selector")

    def test_relative_link_layout_check(self):
        target = self.root / "lib/target"
        target.touch()
        link = self.root / "lib/link"
        link.symlink_to("target")
        self.step("check-symlinks", paths=["lib/link"])
        link.unlink()
        link.symlink_to(target)
        self.step("check-symlinks", paths=["lib/link"], fail="expected relative output symlink")
        link.unlink()
        link.symlink_to("../../outside")
        (self.work / "outside").touch()
        self.step("check-symlinks", paths=["lib/link"], fail="not in the subpath")

    def test_rpath_shrink_explicit_dlopen_retention_and_audit(self):
        path = self.shared(rpath=f"{UNUSED}/lib:{GMP}/lib")
        log = self.work / "patchelf.jsonl"
        selected = self.wrapper("selected-patchelf", f'''import json, subprocess, sys
with open({str(log)!r}, 'a') as stream: stream.write(json.dumps(sys.argv[1:]) + '\\n')
subprocess.run([{self.config['patchelf']!r}, *sys.argv[1:]], check=True)
''')
        self.step("rpaths", patchelf=selected, dlopenDirectories=[f"{GMP}/lib"])
        rpath = command(self.config["patchelf"], "--print-rpath", path).decode().strip()
        self.assertNotIn(f"{UNUSED}/lib", rpath.split(":"))
        self.assertIn(f"{GMP}/lib", rpath.split(":"))
        calls = [json.loads(line)[0] for line in log.read_text().splitlines()]
        self.assertIn("--shrink-rpath", calls)
        self.assertIn("--set-rpath", calls)
        self.step("check-paths")  # Assertion filename /build/source/assert.c is allowed.
        self.step("rpaths", dlopenDirectories=[str(self.work)], fail="expected existing store directory")
        self.step("rpaths", dlopenDirectories=[f"{GMP}/../bad"], fail="expected existing store directory")
        for bad in (self.work / "earlier-build/source", self.work / "current-tmp/tmp"):
            bad.mkdir(parents=True)
            command(self.config["patchelf"], "--set-rpath", bad, path)
            self.step("check-paths", fail="forbidden build lookup path")
        command(self.config["patchelf"], "--set-rpath", f"{GMP}/does-not-exist", path)
        self.step("check-paths", fail="nonexistent runtime lookup path")

    def test_interpreter_and_needed_lookup_audit(self):
        source = self.work / "main.c"
        source.write_text("int main(void) { return 0; }\n")
        path = self.root / "lib/executable"
        command(CC, source, "-o", path)
        self.step("rpaths")
        self.step("check-paths")
        command(self.config["patchelf"], "--set-interpreter", self.work / "earlier-build/ld.so", path)
        self.step("check-paths", fail="forbidden build lookup path")
        path.unlink()
        path = self.shared()
        self.step("rpaths")
        command(self.config["patchelf"], "--add-needed", self.work / "current-tmp/libbad.so", path)
        self.step("check-paths", fail="forbidden build lookup path")


if __name__ == "__main__":
    unittest.main(verbosity=2)

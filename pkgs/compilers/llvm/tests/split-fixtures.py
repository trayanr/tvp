"""Tiny offline copy/native-byte controls. No compiler or LLVM executable runs."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[4]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def native_object(value, section=b'.rodata.str1.1'):
    names = b'\0.shstrtab\0' + section + b'\0'
    data = b'\0' + value + b'\0'
    payload = 64 + len(names)
    shoff = payload + len(data)
    header = b'\x7fELF\x02\x01\x01' + b'\0' * 9
    header += struct.pack('<HHIQQQIHHHHHH', 1, 62, 1, 0, 0, shoff, 0, 64, 0, 0, 64, 3, 1)
    table = b'\0' * 64
    table += struct.pack('<IIQQQQIIQQ', 1, 3, 0, 0, 64, len(names), 0, 0, 1, 0)
    table += struct.pack('<IIQQQQIIQQ', 11, 1, 2, 0, payload, len(data), 0, 0, 1, 1)
    return header + names + data + table


def archive(data):
    header = b'paths.o/        ' + b'0           ' + b'0     ' + b'0     ' + b'100644  '
    header += str(len(data)).encode().ljust(10) + b'`\n'
    assert len(header) == 60
    return b'!<arch>\n' + header + data + (b'\n' if len(data) % 2 else b'')


def tree_state(root):
    state = {}
    for path in sorted(root.rglob('*')):
        info = path.lstat()
        if path.is_symlink():
            value = ('link', os.readlink(path))
        elif path.is_file():
            value = ('file', path.read_bytes(), info.st_mode, info.st_mtime_ns, info.st_ino)
        else:
            value = ('directory', info.st_mode)
        state[str(path.relative_to(root))] = value
    return state


def main():
    proof = json.loads(Path(sys.argv[1]).read_text())
    result = {}
    with tempfile.TemporaryDirectory(prefix='llvm-copy-') as work:
        work = Path(work)
        artifact, final = work/'artifact', work/'final'
        artifact.mkdir()
        (artifact/'nix-support').mkdir()
        (artifact/'nix-support/source-date-epoch').write_text('123\n')
        (artifact/'payload').write_bytes(b'copy fixture\0bytes')
        os.link(artifact/'payload', artifact/'alias')
        (artifact/'link').symlink_to('payload')
        command = proof['copy']
        assert 'TVP_ARTIFACT_OUTPUTS' not in command
        env = dict(os.environ, TVP_ARTIFACT_ROOT=str(artifact), out=str(final))
        subprocess.run(['bash', '-euc', command], cwd=work, env=env, check=True)
        assert (final/'payload').read_bytes() == b'copy fixture\0bytes'
        assert os.path.samefile(final/'payload', final/'alias')
        assert os.readlink(final/'link') == 'payload'
        assert (work/'source-date-epoch').read_text() == '123\n'
        result['selectedScalarCopy'] = True
    ruby = load('llvm_fixture_paths', ROOT/'pkgs/runtimes/ruby/owned/finalize.py')
    old = b'/nix/store/' + b'a'*32 + b'-llvm-23.1.4'
    new = b'/nix/store/' + b'b'*32 + b'-llvm-23.1.4'
    obj = native_object(old+b'/lib')
    changed = ruby.object_paths(obj, old, new)
    assert len(changed) == len(obj) and changed == obj.replace(old, new)
    result['nativeReadonlyEqualWidth'] = True
    for data in [native_object(b'not-a-path:'+old), native_object(old+b'/lib', b'.gnu.lto_payload')]:
        try:
            ruby.object_paths(data, old, new)
        except ValueError:
            pass
        else:
            raise AssertionError('unsafe native payload accepted')
    result['nonPathAndLTORejected'] = True
    # Full adapter on a synthetic native archive + text/links; inspectors are
    # availability inputs only here. No dynamic ELF exists, so none is invoked.
    readelf = str(Path(shutil.which('readelf')).resolve())
    assert readelf.startswith('/nix/store/')
    config = {
        'readelf': readelf, 'patchelf': readelf, 'ar': readelf,
        'rubyFinalizer': str(ROOT/'pkgs/runtimes/ruby/owned/finalize.py'),
        'archiveFinalizer': str(ROOT/'pkgs/libraries/libxml2/ordinary/finalize.py'),
        'archiveElfFinalizer': str(ROOT/'pkgs/libraries/libxml2/ordinary/elf.py'),
    }
    script = ROOT/'pkgs/compilers/llvm/native/finalize.py'
    shared = ROOT/'pkgs/runtimes/perl/ordinary/elf-finalize.py'
    with tempfile.TemporaryDirectory(prefix='llvm-bytes-') as work:
        base = Path(work)
        # Match Nix's individual, differently named store-file inputs. A
        # repository-directory import must not hide a missing sibling module.
        flat = base/'inputs'
        flat.mkdir()
        for index, key in enumerate(('rubyFinalizer', 'archiveFinalizer', 'archiveElfFinalizer')):
            target = flat/f'source-{index}.py'
            shutil.copyfile(config[key], target)
            config[key] = str(target)
        staged_script = flat/'adapter.py'
        staged_shared = flat/'namespace.py'
        shutil.copyfile(script, staged_script)
        shutil.copyfile(shared, staged_shared)
        assert not (flat/'elf.py').exists()
        root = base/('f' * (len(old) - len(os.fsencode(base)) - 1))
        root.mkdir(); (root/'lib').mkdir()
        original = archive(obj)
        (root/'lib/libFixture.a').write_bytes(original)
        os.link(root/'lib/libFixture.a', root/'lib/libAlias.a')
        (root/'metadata').write_bytes(old+b'/lib\n')
        (root/'alias').symlink_to(old.decode()+'/metadata')
        run = [sys.executable, '-B', str(staged_script), json.dumps(config), str(root), old.decode(), str(staged_shared)]
        clean = dict(os.environ)
        clean.pop('PYTHONPATH', None)
        subprocess.run(run, check=True, capture_output=True, env=clean)
        result['standaloneHelperInputs'] = True
        updated = (root/'lib/libFixture.a').read_bytes()
        assert updated == original.replace(old, os.fsencode(root))
        assert os.path.samefile(root/'lib/libFixture.a', root/'lib/libAlias.a')
        assert (root/'metadata').read_bytes() == os.fsencode(root)+b'/lib\n'
        assert (root/'alias').resolve() == root/'metadata'
        result['completeArchiveTextAliases'] = True
        # Bitcode/serialized or signed-looking members are never byte-patched.
        (root/'lib/libFixture.a').write_bytes(archive(b'BC\xc0\xde'+old))
        before = (root/'lib/libFixture.a').read_bytes()
        failed = subprocess.run(run, capture_output=True, env=clean)
        assert failed.returncode != 0 and (root/'lib/libFixture.a').read_bytes() == before
        result['serializedArchiveRejectedUnchanged'] = True
        # Stage a valid archive, native object and text before another payload
        # rejects. Neither staged updates nor Ruby's earlier write pass may
        # mutate the installed tree on that failure.
        (root/'lib/libFixture.a').write_bytes(original)
        (root/'lib/native.o').write_bytes(obj)
        (root/'metadata').write_bytes(old+b'/lib\n')
        invalid = root/'lib/zz-invalid'
        invalid.write_bytes(b'unsupported\0'+old+b'/lib')
        before = tree_state(root)
        failed = subprocess.run(run, capture_output=True, env=clean)
        assert failed.returncode != 0 and tree_state(root) == before
        result['mixedPayloadRejectedUnchanged'] = True
        invalid.unlink()
        # Preserve the kernel's directory requirement for a file/. spelling;
        # link validation must finish before any payload is committed.
        invalid_link = root/'lib/zz-link'
        invalid_link.symlink_to('native.o/.')
        before = tree_state(root)
        failed = subprocess.run(run, capture_output=True, env=clean)
        assert failed.returncode != 0 and tree_state(root) == before
        result['namespaceRejectedUnchanged'] = True
        invalid_link.unlink()
        subprocess.run(run, check=True, capture_output=True, env=clean)
        assert (root/'lib/native.o').read_bytes() == obj.replace(old, os.fsencode(root))
        result['nativeObjectTransport'] = True
    for step in proof['shell']:
        subprocess.run(['bash', '-n'], input=step['run'], text=True, check=True)
    result['selectedShellSyntax'] = True
    print(json.dumps(result, sort_keys=True))


if __name__ == '__main__':
    main()

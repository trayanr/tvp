"""Bounded source/finalization and raw-evidence interface regressions; no packages."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ordinary = Path(__file__).resolve().parents[1]/'ordinary'
sys.path.insert(0, str(ordinary))
from prepare import prepare
from classify import classify
from capture import capture
from finalize import archive, finalize


def rejects(fn):
    try: fn()
    except (ValueError, OSError, subprocess.CalledProcessError): return
    raise AssertionError('unsafe/unqualified fixture accepted')


shell,cc,readelf,ar,patchelf = sys.argv[1:]
with tempfile.TemporaryDirectory() as temp:
    tmp=Path(temp)
    source=tmp/'source'; source.mkdir()
    (source/'configure').write_bytes(b'#!/bin/sh\n/usr/bin/file\n')
    (source/'ltmain.sh').write_bytes(b"#!/bin/sh\neval sys_lib_search_path=host\neval sys_lib_dlsearch_path=host\n")
    prepare(source,shell,[])
    assert (source/'configure').read_bytes().startswith(b'#!'+shell.encode())
    assert b'host' not in (source/'ltmain.sh').read_bytes()
    (source/'configure').write_bytes(b'#!/bin/sh\nunchanged\n')
    (source/'ltmain.sh').write_bytes(b'#!/bin/sh\nbad\0body')
    rejects(lambda:prepare(source,shell,[]))
    assert (source/'configure').read_bytes()==b'#!/bin/sh\nunchanged\n'
    (source/'ltmain.sh').unlink(); (source/'ltmain.sh').symlink_to(source/'configure')
    rejects(lambda:prepare(source,shell,[]))
    raw=tmp/'raw'
    capture(raw,[sys.executable,'-c','print("Total 12 tests, no errors")'])
    assert classify(raw,'2.7.4')['summaryPresent']
    original=(raw/'stdout').read_bytes()
    (raw/'stdout').write_bytes(original+b'unknown additional record\n')
    rejects(lambda:classify(raw,'2.7.4'))
    (raw/'stdout').write_bytes(original)
    (raw/'runsuite.log').write_text('Failed to detect incorrect RNG line 616\n')
    rejects(lambda:classify(raw,'2.7.4'))
    assert (raw/'stdout').read_bytes()==original
    (raw/'runsuite.log').unlink(); (raw/'stdout').write_text('no tests\n')
    rejects(lambda:classify(raw,'2.7.4'))
    (raw/'stdout').write_bytes(original); (raw/'exit.json').write_text('{"exit":1}')
    rejects(lambda:classify(raw,'2.7.4'))
    # A compiled object/archive is a tiny cached-tool fixture, not a producer build.
    old=b'/nix/store/'+b'1'*32+b'-libxml2-2.7.4'
    new=b'/nix/store/'+b'2'*32+b'-libxml2-2.7.4'
    c=tmp/'slot.c'; obj=tmp/'slot.o'; lib=tmp/'lib.a'
    c.write_bytes(b'const char *catalog="'+old+b'/etc/xml/catalog";\n')
    subprocess.run([cc,'-c','-O2',str(c),'-o',str(obj)],check=True)
    subprocess.run([ar,'rcD',str(lib),str(obj)],check=True)
    updated=archive(lib.read_bytes(),old,new,readelf)
    assert old not in updated and new in updated and len(updated)==lib.stat().st_size
    # A dynamic fixture proves exclusively owned RPATH and readonly catalog
    # relocation without compiling any catalogue package.
    so=tmp/'slot.so'
    subprocess.run([cc,'-shared','-fPIC',str(c),'-Wl,-rpath,'+old.decode()+'/lib','-o',str(so)],check=True)
    from finalize import readonly_paths
    changed,dynamic=readonly_paths(so,so.read_bytes(),old,new,readelf)
    assert dynamic and new in changed
    rejects(lambda:readonly_paths(so,so.read_bytes(),old,new,'/no/inspector'))
    # Ordinary metadata relocation uses an equal-width final namespace. Test an
    # alias role conflict and outside symlink before any earlier metadata write.
    root=tmp/('x'*90);root.mkdir();(root/'lib').mkdir();(root/'bin').mkdir()
    (root/'lib/a.pc').write_bytes(old)
    artifact='/nix/store/'+'1'*32+'-'+('x'*(len(str(root))-44))
    (root/'lib/a.pc').write_text(artifact)
    os.link(root/'lib/a.pc',root/'bin/xml2-config')
    rejects(lambda:finalize(root,artifact,readelf,patchelf))
    assert (root/'lib/a.pc').read_text()==artifact
    (root/'bin/xml2-config').unlink(); (root/'bad').symlink_to('/outside-fixture')
    rejects(lambda:finalize(root,artifact,readelf,patchelf))
    assert (root/'lib/a.pc').read_text()==artifact
    (root/'bad').unlink()
    finalize(root,artifact,readelf,patchelf)
    assert (root/'lib/a.pc').read_text()==str(root)
print('source, raw replay, archive relocation and mutation guards passed')

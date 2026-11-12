"""Retain/reassemble compiled OpenJDK products, never compile or edit archives.

The checkpoint includes native make metadata, compiled modules, native module
inputs, exploded tools and image data. Source is restricted to legal/module
metadata. Native CreateJmods/Images regenerate hashes, CDS and src.zip packaging.
"""
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
import tarfile


def restore(sidecar, target):
    layout=json.loads((sidecar/'layout.json').read_text())
    if target.exists() or target.parent.resolve()!=target.parent: raise ValueError('private assembly workspace required')
    with tarfile.open(sidecar/'products.tar') as archive:
        members=archive.getmembers(); names={m.name for m in members}
        links={m.name for m in members if m.issym()}
        if len(names)!=len(members) or names!=set(layout['members']): raise ValueError('assembly inventory mismatch')
        for m in members:
            p=Path(m.name)
            if p.is_absolute() or '..' in p.parts or any(str(n) in links for n in p.parents):
                raise ValueError('unsafe assembly namespace')
            if m.issym() or m.islnk():
                value=os.path.normpath(str(p.parent/m.linkname) if m.issym() else m.linkname)
                if os.path.isabs(m.linkname) or value not in names: raise ValueError('external assembly link')
            elif not (m.isfile() or m.isdir()): raise ValueError('special assembly node')
        target.mkdir(); archive.extractall(target,filter='fully_trusted')
    pending=[]
    for parent, dirs, files in os.walk(target,followlinks=False):
        for p in [Path(parent)]+[Path(parent)/n for n in files]:
            if not p.is_symlink(): p.chmod(p.stat().st_mode | 0o200)
    # Generated text spec roots only. Native/class/jar/jmod payloads are never
    # substituted. The original checkpoint and configure provenance are immutable.
    for p in (target/'build'/layout['configuration']).glob('*.gmk'):
        data=p.read_bytes()
        if b'\0' in data: raise ValueError('nontext assembly spec')
        data.decode('utf-8')
        pending.append((p,data.replace(layout['root'].encode(),str(target).encode())))
    for p,data in pending: p.write_bytes(data)
    return layout


def mirror(raw, public, assembly, conf):
    """Map native module inputs to exact corresponding public image products."""
    pending=[]
    for directory, installed in (('modules_libs','lib'),('modules_cmds','bin')):
        top=assembly/'build'/conf/'support'/directory
        for module in sorted(top.iterdir()):
            if not module.is_dir() or module.is_symlink(): raise ValueError('invalid native module namespace')
            for p in sorted(module.rglob('*')):
                if not p.is_file() or p.is_symlink(): continue
                data=p.read_bytes()
                if not data.startswith(b'\x7fELF'): continue
                relative=Path(installed)/p.relative_to(module)
                before=raw/relative; after=public/relative
                if (not before.is_file() or not after.is_file() or before.is_symlink() or after.is_symlink()
                        or before.read_bytes()!=data or not after.read_bytes().startswith(b'\x7fELF')):
                    raise ValueError(('unmatched native module product',str(p),str(relative)))
                pending.append((p,after.read_bytes()))
    if not pending: raise ValueError('empty native module map')
    # Full map validation before the first changed private native write.
    for p,data in pending:
        if p.read_bytes()!=data:
            info=p.stat(); p.write_bytes(data); os.utime(p,ns=(info.st_atime_ns,info.st_mtime_ns))


def commands(make, shell, public, assembly, conf, false, image="images/jdk"):
    build=assembly/'build'/conf
    common=[make,'-r','-R','-I',str(assembly/'make/common'),f'SPEC={build}/spec.gmk',
            f'JDK_IMAGE_DIR={build/image}',f'SHELL={shell}',f'JMOD={public}/bin/jmod',f'JMOD_CMD={public}/bin/jmod',
            f'JLINK={public}/bin/jlink',f'JLINK_CMD={public}/bin/jlink',
            f'JAVA={public}/bin/java',f'JAVA_CMD={public}/bin/java',
            f'CC={false}',f'CXX={false}',f'JAVAC={false}',f'JAVAC_CMD={false}',
            'CREATING_BUILDJDK=false','INTERIM_JMOD=false']
    modules=sorted(p.name for p in (build/'jdk/modules').iterdir() if p.is_dir())
    if 'java.base' not in modules: raise ValueError('no java.base compiled module')
    result=[common+['-f',str(assembly/'make/CreateJmods.gmk'),f'MODULE={m}','all']
            for m in modules if m!='java.base']
    result.append(common+['-f',str(assembly/'make/CreateJmods.gmk'),'MODULE=java.base','all'])
    result.append(common+['-f',str(assembly/'make/Images.gmk'),'jdk'])
    return result


def assemble(sidecar, raw, public, target, make, shell, false, image):
    if Path(image).is_absolute() or '..' in Path(image).parts or not Path(image).parts:
        raise ValueError('relative selected image directory required')
    layout=restore(sidecar,target); conf=layout['configuration']
    mirror(raw,public,target,conf)
    build=target/'build'/conf
    # No stale JMOD/hash/image/CDS products may bypass native regeneration.
    for name in ('images/jmods','support/images',image):
        p=build/name
        if p.exists(): shutil.rmtree(p)
    cmds=commands(make,shell,public,target,conf,false,image)
    for argv in cmds: subprocess.run(argv,cwd=target,check=True)
    assembled=build/image
    if not (assembled/'lib/src.zip').is_file() or not (assembled/'release').is_file():
        raise ValueError('incomplete JDK packaged image')
    # The public path stays fixed for native RPATHs; overwrite image contents,
    # preserving the recipe's nix-support receipt. Native Images controls CDS.
    for p in public.iterdir():
        if p.name!='nix-support':
            if p.is_dir() and not p.is_symlink(): shutil.rmtree(p)
            else: p.unlink()
    shutil.copytree(assembled,public,dirs_exist_ok=True,symlinks=True)


if __name__=='__main__':
    action=sys.argv[1]
    if action=='assemble': assemble(*[Path(x) if i<4 else x for i,x in enumerate(sys.argv[2:])])
    else: raise ValueError('unknown assembly action')

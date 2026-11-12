"""Production-only JDK assembly-input selection; no final packaging code."""
import json
import os
from pathlib import Path
import re
import sys
import tarfile


SUPPORT = ('modules_libs','modules_cmds','modules_conf','modules_include',
           'modules_man','modules_legal','link_opt','src.zip','demos/image')


def selected(root, conf):
    build=Path('build')/conf
    names={}
    def add(path):
        if path.is_symlink() or path.is_file(): names[str(path.relative_to(root))]=path
        elif path.is_dir():
            names[str(path.relative_to(root))]=path
            for item in sorted(path.iterdir()): add(item)
    add(root/'make')
    for path in (root/'src').rglob('*'):
        if path.name=='module-info.java' or 'legal' in path.relative_to(root/'src').parts:
            add(path)
    add(root/build/'jdk')
    for item in SUPPORT:
        path=root/build/'support'/item
        if path.exists(): add(path)
    for pattern in ('*.gmk','*.sh'):
        for path in (root/build).glob(pattern): add(path)
    for name in ('spec.gmk','jdk/modules/java.base/module-info.class','jdk/release','support/src.zip',
                 'support/modules_libs','support/modules_cmds'):
        if not (root/build/name).exists(): raise ValueError(('missing JDK assembly prerequisite',name))
    for name in ('CreateJmods.gmk','Images.gmk'):
        if not (root/'make'/name).is_file(): raise ValueError('missing native packaging makefile')
    return names


def save(root, dest, conf):
    if root.resolve()!=root or dest.exists() or not re.fullmatch(r'[A-Za-z0-9_.-]+',conf):
        raise ValueError('private assembly roots/configuration required')
    names=selected(root,conf)
    for name,p in names.items():
        if p.is_symlink():
            target=os.path.normpath(str(Path(name).parent/os.readlink(p)))
            if os.path.isabs(os.readlink(p)) or target not in names:
                raise ValueError(('unretained assembly alias',name))
        elif not (p.is_file() or p.is_dir()): raise ValueError('special assembly member')
    dest.mkdir(parents=True)
    with tarfile.open(dest/'products.tar','w',format=tarfile.PAX_FORMAT) as archive:
        for name,p in sorted(names.items()): archive.add(p,arcname=name,recursive=False)
    (dest/'layout.json').write_text(json.dumps({'root':str(root),'configuration':conf,
        'members':sorted(names)},sort_keys=True)+'\n')



if __name__=='__main__':
    if sys.argv[1]!='save': raise ValueError('unknown checkpoint action')
    save(Path(sys.argv[2]),Path(sys.argv[3]),sys.argv[4])

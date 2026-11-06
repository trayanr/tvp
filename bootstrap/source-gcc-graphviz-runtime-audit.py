"""Require prior observers and recheck overlap before new native permissions."""
import importlib
import json
from pathlib import Path
import re
import sys
import audit
ROOT=Path(__file__).resolve().parent
strict=importlib.import_module('gnu-runtime-audit')
boundary=importlib.import_module('source-cmake-prerequisite-runtime-audit')
require_paths=importlib.import_module('source-full-gcc-prerequisite-runtime-audit').require_paths

def stable(row):
    return {k: re.sub(r'0x[0-9a-f]+','0xADDR',v) if k=='actualLoaderListing' and v else v for k,v in row.items()}

def run(origin):
    assert origin['failures']==[]
    prior=importlib.import_module('source-gcc-python-runtime-audit').run(origin)
    assert prior['failures']==[]
    core=importlib.import_module('source-gcc-test-harness-runtime-audit').run(origin)
    assert core['failures']==[]
    prior_permissions=set(prior['permittedNative'])|set(core['permittedNative'])
    m=audit.nix_json('eval','--json','--impure','--expr',f'''
      let t=import {ROOT}/source-gcc-graphviz-validation.nix {{}}; f=t.f;
      in {{ packages=builtins.mapAttrs (_: x: toString x) f.packages;
        native=map toString [f.previous.harness.native.profile.libc
          f.previous.harness.native.profile.libgcc f.previous.harness.native.profile.libstdcxx
          f.previous.harness.prerequisites.zlib
          (import {ROOT}/source-python-meson.nix {{}}).prerequisites.bzip2];
        loader="${{f.previous.harness.native.profile.libc}}/lib/ld-linux-x86-64.so.2";
        readelf="${{f.tools.binutils}}/bin/readelf";
        fonts=toString f.fonts; evidence=toString t.consumer.evidence;
        perl=toString f.tools.perl; shell=toString f.composition.bash; shellLibc=toString (import {ROOT} {{}}).gnu-libc;
        m4=toString f.tools.m4; bison=toString f.tools.bison;
      }}''')
    permitted=set(m['native']+list(m['packages'].values()))
    assert permitted<=strict.executable_outputs(origin)
    assert m['fonts'] not in permitted
    assert not permitted & set(origin['runtimeForbiddenExecutableRoots'])
    roots=sorted({'/'.join(p.split('/')[:4]) for p in prior['files']})
    old,failures=boundary.scan(roots,prior_permissions,m['loader'],m['readelf'])
    assert set(old)==set(prior['files'])
    mismatches={p:dict(before=stable(prior['files'][p]),after=stable(row)) for p,row in old.items() if stable(row)!=stable(prior['files'][p])}
    if mismatches:raise ValueError(json.dumps(mismatches,indent=2))
    files,newfail=boundary.scan(list(m['packages'].values()),permitted,m['loader'],m['readelf']);failures+=newfail
    overlap=set(files)&set(old);assert all(stable(files[p])==stable(old[p]) for p in overlap)
    commands=json.loads((Path(m['evidence'])/'commands.json').read_text())
    trace='\n'.join(c['stderr'] for c in commands if c['name'] in {'loader','loader-svg'})
    actual=re.findall(r'calling init: (/\S+)',trace)
    require_paths(actual,permitted)
    for name in ['libgvplugin_gd','libgvplugin_core','libgvplugin_dot_layout','libfontconfig','libfreetype','libpng16','libexpat','libltdl']:
        assert any(name in path for path in actual),name
    scripts={}
    for root in m['packages'].values():
        for path in (Path(root)/'bin').glob('*'):
            if path.is_file() and not path.is_symlink() and path.read_bytes().startswith(b'#!'):
                interpreter=path.read_bytes().split(b'\n',1)[0][2:].decode().split()[0]
                if not strict.owned_executable(interpreter,{m['shell'],m['perl']}):failures.append('Foreign script: '+str(path))
                scripts[str(path)]=interpreter
    data={}
    for path in Path(m['fonts']).rglob('*'):
        if not path.is_file():continue
        payload=path.read_bytes()
        assert not payload.startswith((b'\x7fELF',b'#!')) and not path.stat().st_mode & 0o111
        data[str(path)]=len(payload)
    known=strict.origin_paths(origin)
    raw=audit.nix_json('path-info','--json','--recursive',*m['packages'].values(),m['fonts'])
    closure=sorted(raw if isinstance(raw,dict) else (r['path'] for r in raw))
    if set(closure)-set(known):failures.append('Unclassified Graphviz reference closure')
    summary=json.loads((Path(m['evidence'])/'summary.json').read_text());assert summary['result']=='PASS'
    return dict(schema=1,failures=failures,files=old|files,permittedNative=sorted(prior_permissions|permitted),
        newNativePermission=sorted(permitted),priorPythonCompared=dict(files=len(old),exactProviders=True,normalized='ASLR addresses only'),
        loaderTrace=trace,loadedNative=actual,installedScripts=scripts,fontData=dict(root=m['fonts'],executablePermission=False,files=data),
        constructionGenerators=dict(m4=m['m4'],bison=m['bison'],role='reused earlier construction generation; not rendering-native permission'),
        referenceClosure=closure,summary=summary)

if __name__=='__main__':
    result=run(json.loads(Path(sys.argv[1]).read_text()));print(json.dumps(result,indent=2,sort_keys=True));sys.exit(bool(result['failures']))

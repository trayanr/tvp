"""Keep host-tool ancestry separate from new compiler target permissions."""
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
    return {k:re.sub(r'0x[0-9a-f]+','0xADDR',v) if k=='actualLoaderListing' and v else v for k,v in row.items()}

def run(origin):
    assert origin['failures']==[]
    prior=importlib.import_module('source-gcc-graphviz-runtime-audit').run(origin)
    assert prior['failures']==[]
    m=audit.nix_json('eval','--json','--impure','--expr',f'''
      let t=import {ROOT}/source-full-gcc-validation.nix {{}}; f=t.f; p=f.prerequisites;
      in {{ file=toString f.file; compiler=toString f.compiler; driver=toString f.driver;
        fileNative=map toString [f.file f.native.profile.libc p.zlib p.zstd f.native.prior.prerequisites.xz f.native.prior.prerequisites.bzip2];
        native=map toString [f.compiler f.native.profile.libc p.gmp p.mpfr p.mpc p.isl p.zlib p.zstd p.libxcrypt];
        loader="${{f.native.profile.libc}}/lib/ld-linux-x86-64.so.2";
        readelf="${{f.native.binutils}}/bin/readelf"; evidence=toString t.consumer.evidence;
      }}''')
    permitted=set(m['native']);assert permitted<=strict.executable_outputs(origin)
    assert not permitted & set(origin['runtimeForbiddenExecutableRoots'])
    old_permissions=set(prior['permittedNative'])
    roots=sorted({'/'.join(p.split('/')[:4]) for p in prior['files']})
    old,failures=boundary.scan(roots,old_permissions,m['loader'],m['readelf'])
    assert set(old)==set(prior['files'])
    assert all(stable(v)==stable(prior['files'][p]) for p,v in old.items()),'Prior providers changed'
    files,newfail=boundary.scan([m['compiler']],permitted,m['loader'],m['readelf']);failures+=newfail
    file_permission=set(m['fileNative'])
    assert file_permission<=strict.executable_outputs(origin)
    assert not file_permission & set(origin['runtimeForbiddenExecutableRoots'])
    host_files,host_failures=boundary.scan([m['file']],old_permissions|file_permission,m['loader'],m['readelf'])
    failures+=host_failures
    files=files|host_files
    commands=json.loads((Path(m['evidence'])/'commands.json').read_text())
    traces={}
    for name in ['runtime','openmp','atomic','itm','quadmath','sanitizers']:
        command=next(c for c in commands if c['name']==name)
        paths=re.findall(r'calling init: (/\S+)',command['stderr'])
        require_paths(paths,{m['compiler'],m['loader'].rsplit('/lib/',1)[0]})
        traces[name]=paths
    return dict(schema=1,failures=failures,files=old|files,permittedNative=sorted(old_permissions|permitted|file_permission),
        compilerHostPermission=sorted(permitted),targetPermission=sorted({m['compiler'],m['loader'].rsplit('/lib/',1)[0]}),testToolPermission=sorted(file_permission),priorGraphvizCompared=dict(files=len(old),exactProviders=True,normalized='ASLR addresses only'),
        installedConsumerLoads=traces,hostToolAncestry='Earlier prerequisite runtimes retained under prior independently audited permissions')

if __name__=='__main__':
    result=run(json.loads(Path(sys.argv[1]).read_text()));print(json.dumps(result,indent=2,sort_keys=True));sys.exit(bool(result['failures']))

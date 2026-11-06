"""Pure module provenance never grants permission to an imported native library."""
import hashlib
import importlib
import json
from pathlib import Path
import re
import sys
import audit

ROOT = Path(__file__).resolve().parent
strict = importlib.import_module('gnu-runtime-audit')
boundary = importlib.import_module('source-cmake-prerequisite-runtime-audit')
require_paths = importlib.import_module('source-full-gcc-prerequisite-runtime-audit').require_paths


def run(origin):
    if origin['failures']:
        raise ValueError('Construction audit failed')
    prior = importlib.import_module('source-gcc-test-harness-runtime-audit').run(origin)
    if prior['failures']:
        raise ValueError('Prior core harness runtime audit failed')
    m = audit.nix_json('eval', '--json', '--impure', '--expr', f'''
      let t=import {ROOT}/source-gcc-python-validation.nix {{}}; f=t.f;
          p=import {ROOT}/source-python-meson.nix {{}}; b=import {ROOT} {{}};
      in {{ packages=builtins.mapAttrs (_: x: toString x) f.packages;
            profile=toString f.profile; consumer=toString t.consumer;
            evidence=toString t.consumer.evidence;
            python=toString f.tools.python;
            native=map toString [f.harness.native.profile.libc
              p.pythonOpenssl p.prerequisites.zlib p.prerequisites.bzip2 p.prerequisites.xz];
            shell=toString f.composition.bash; shellLibc=toString b.gnu-libc;
            loader="${{f.harness.native.profile.libc}}/lib/ld-linux-x86-64.so.2";
            readelf="${{f.tools.binutils}}/bin/readelf"; }}''')
    # No newly built package is a permitted ELF provider in this pure profile.
    permitted = set(m['native'] + [m['python'], m['shell']])
    shell_native={m['shell'],m['shellLibc']}
    assert permitted | shell_native <= strict.executable_outputs(origin)
    assert not permitted & set(origin['runtimeForbiddenExecutableRoots'])
    files, failures = boundary.scan([m['python']], permitted, m['loader'], m['readelf'])
    # Re-inspect exactly the core roots using its independently bounded native
    # generation, compare all overlapping file records, and only then union.
    core_roots=sorted({'/'.join(p.split('/')[:4]) for p in prior['files']})
    observed, core_failures=boundary.scan(core_roots,set(prior['permittedNative']),m['loader'],m['readelf'])
    def stable(record):
        # Loader addresses vary under ASLR; paths, ELF headers, RPATHs and
        # resolved providers must agree independently. Retain both raw listings.
        return {k:(re.sub(r'0x[0-9a-f]+','0xADDR',v) if k=='actualLoaderListing' and v else v)
                for k,v in record.items()}
    assert set(observed)==set(prior['files'])
    assert all(stable(v)==stable(prior['files'][p]) for p,v in observed.items()), 'Prior core ELF providers changed'
    overlap=set(files)&set(observed)
    assert all(stable(files[p])==stable(observed[p]) for p in overlap)
    failures+=core_failures
    files=observed|files
    scripts, source = {}, {}
    for root in list(m['packages'].values()) + [m['profile']]:
        entries = {}
        for path in Path(root).rglob('*'):
            if not path.is_file():
                continue
            data=path.read_bytes()
            if data.startswith(b'\x7fELF') or path.suffix in {'.so','.pyd','.dll','.exe'}:
                failures.append('Native payload in pure Python output: '+str(path))
            if path.parent.name=='bin' and not path.is_symlink():
                interpreter=data.split(b'\n',1)[0][2:].decode().split()[0]
                if not data.startswith(b'#!') or interpreter!=m['shell']+'/bin/bash':
                    failures.append('Unexpected script interpreter: '+str(path))
                scripts[str(path)]=interpreter
            entries[str(path.relative_to(root))]=hashlib.sha256(data).hexdigest()
        source[root]=dict(role='pinned source Python modules/metadata; no ELF permission',files=entries)
    known=strict.origin_paths(origin)
    raw=audit.nix_json('path-info','--json','--recursive',m['profile'],m['consumer'],*m['packages'].values())
    closure=sorted(raw if isinstance(raw,dict) else (x['path'] for x in raw))
    if set(closure)-set(known):
        failures.append('Unclassified Python reference closure')
    evidence=Path(m['evidence'])
    providers=json.loads((evidence/'providers.json').read_text())
    mapped=sorted({line.split()[-1] for line in providers['maps'].splitlines()
                   if '/nix/store/' in line and 'x' in line.split()[1]})
    require_paths(mapped,permitted)
    commands=json.loads((evidence/'commands.json').read_text())
    actual=[]
    for command in commands:
        if command['name'] not in {'providers','cli-loader'}:continue
        groups={}
        for pid,path in re.findall(r'^\s*(\d+):\s+calling init: (/\S+)',command['stderr'],re.M):
            groups.setdefault(pid,[]).append(path)
        images=[]
        for paths in groups.values():
            chunks=[]
            for path in paths:
                if path.endswith('/ld-linux-x86-64.so.2'):
                    chunks.append([])
                assert chunks, 'Library initialization before an owned loader'
                chunks[-1].append(path)
            if command['name']=='providers':
                assert len(chunks)==1
                require_paths(chunks[0],permitted)
            else:
                assert len(chunks)==2
                assert chunks[0][0]==m['shellLibc']+'/lib/ld-linux-x86-64.so.2'
                assert chunks[1][0]==m['loader']
                require_paths(chunks[0],shell_native)
                require_paths(chunks[1],permitted)
            images+=chunks
        assert groups
        actual.append(dict(name=command['name'],processes=groups,orderedImageLoads=images))
    assert len(actual)==2
    summary=json.loads((evidence/'summary.json').read_text());assert summary['result']=='PASS'
    return dict(schema=1,failures=failures,priorCoreRuntimeFiles=len(prior['files']),
        priorCoreCompared=dict(files=len(observed),exactProviders=True,normalized='ASLR addresses only',raw=prior['files']),permittedNative=sorted(permitted),launcherNative=sorted(shell_native),files=files,installedScripts=scripts,
        moduleSourceData=source,extensionProcessMaps=mapped,actualLoaderExecutions=actual,
        installedProviders=providers['distributions'],summary=summary,referenceClosure=closure)


if __name__=='__main__':
    result=run(json.loads(Path(sys.argv[1]).read_text()))
    print(json.dumps(result,indent=2,sort_keys=True))
    sys.exit(bool(result['failures']))

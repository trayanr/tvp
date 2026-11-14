"""Finite production mutation controls. No Perl source compilation."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    return module


def main(config, source):
    f = load('finalizer', source/'ordinary/elf-finalize.py')
    prepare = load('prepare', source/'ordinary/prepare.py')
    old = config['cache']
    results = []
    with tempfile.TemporaryDirectory(prefix='perl-guards-') as temporary:
        parent = Path(temporary)
        counter = 0
        def fixture():
            nonlocal counter
            counter += 1
            root = parent / (str(counter)+'x'*(len(old)-len(str(parent))-len(str(counter))-1))
            assert len(str(root)) == len(old)
            root.mkdir()
            (root/'Config.pm').write_text("prefix='"+old+"'\n")
            return root
        def snapshot(root):
            return {str(p.relative_to(root)):(os.readlink(p) if p.is_symlink() else p.read_bytes())
                    for p in root.rglob('*') if p.is_symlink() or p.is_file()}
        def reject(label, change, update=None):
            root=fixture();change(root);before=snapshot(root)
            c={'root':str(root),'artifact':old, **config['tools']};c.update(update or {})
            try:f.finalize(c)
            except (ValueError, OSError, UnicodeError, subprocess.CalledProcessError) as error:
                assert snapshot(root)==before
                results.append({'control':label,'status':'REJECTED_BEFORE_WRITE','error':repr(error)})
            else:raise AssertionError(('unexpected acceptance',label))
        reject('metadata-NUL',lambda r:(r/'Config.pm').write_bytes(b'bad\0'))
        reject('metadata-encoding',lambda r:(r/'Config.pm').write_bytes(b'\xff'))
        def aliased_metadata(root, target, data):
            p = root/target
            p.parent.mkdir(parents=True, exist_ok=True)
            if p.exists():p.unlink()
            (root/'A-data').write_bytes(data)
            os.link(root/'A-data', p)
        reject('metadata-hardlink-NUL',lambda r:aliased_metadata(r,'Config.pm',b'bad\0'))
        reject('CORE-hardlink-encoding',lambda r:aliased_metadata(r,'lib/CORE/config.h',b'\xff'))
        cwd_config = {'externalPwd':True,'buildPwd':'/nix/store/build-pwd/bin/pwd',
                      'runtimePwd':config['tools']['readelf']}
        reject('Cwd-hardlink-provider-guard',lambda r:aliased_metadata(r,'Cwd.pm',b'no provider'),cwd_config)
        reject('conflicting-hardlink-roles',lambda r:os.link(r/'Config.pm',r/'Cwd.pm'),cwd_config)
        reject('prefix-boundary',lambda r:(r/'other.txt').write_text(old+'extra/lib'))
        reject('outside-hardlink',lambda r:os.link(r/'Config.pm',parent/'outside'))
        reject('escaping-link',lambda r:(r/'link').symlink_to('/etc/passwd'))
        reject('dangling-link',lambda r:(r/'link').symlink_to('absent'))
        reject('link-cycle',lambda r:((r/'a').symlink_to('b'),(r/'b').symlink_to('a')))
        reject('special-node',lambda r:os.mkfifo(r/'fifo'))
        reject('missing-inspector',lambda r:None,{'readelf':'/nix/store/missing-inspector'})
        reject('short-prefix',lambda r:None,{'artifact':old+'-artifacts'})
        root=fixture();(root/'lib').mkdir();(root/'lib/data').write_text('payload')
        (root/'alias').symlink_to(old+'/lib/data')
        os.link(root/'Config.pm',root/'Config-alias.pm')
        result=f.finalize({'root':str(root),'artifact':old,**config['tools']})
        assert (root/'Config.pm').stat().st_ino==(root/'Config-alias.pm').stat().st_ino
        assert (root/'alias').read_text()=='payload'
        results.append({'control':'internal-hardlink-and-absolute-link','status':'PASS'})
        root=fixture()
        original=(cwd_config['buildPwd']+'\n')*5
        (root/'A-data').write_text(original);os.link(root/'A-data',root/'Cwd.pm')
        f.finalize({'root':str(root),'artifact':old,**config['tools'],**cwd_config})
        assert (root/'Cwd.pm').read_text()==(cwd_config['runtimePwd']+'\n')*5
        assert (root/'A-data').stat().st_ino==(root/'Cwd.pm').stat().st_ino
        results.append({'control':'Cwd-hardlink-provider-rebinding','status':'PASS'})
        # A tiny real ELF/shared fixture validates location restrictions and
        # compiled length/suffix semantics without rebuilding any compiler.
        root=fixture();c=parent/'fixture.c'
        c.write_text('#include <stdio.h>\nstatic const char value[]="'+old+'/lib/core";\nint main(void){puts(value);printf("%zu\\n",sizeof(value)-1);return 0;}\n')
        cp=subprocess.run([config['tools']['cc'],str(c),'-o',str(root/'fixture')],capture_output=True,check=True)
        before=(root/'fixture').read_bytes()
        result=f.finalize({'root':str(root),'artifact':old,**config['tools']})
        after=(root/'fixture').read_bytes();assert len(before)==len(after)
        cp=subprocess.run([str(root/'fixture')],capture_output=True,check=True)
        assert cp.stdout==(str(root)+'/lib/core\n'+str(len(old)+9)+'\n').encode(),cp.stdout
        results.append({'control':'real-ELF-equal-width-compiled-size','status':'PASS','mappings':result['elfMappings']})
        root=fixture();(root/'fixture').write_bytes(before)
        # Failing inspector diagnostics must leave even earlier text unchanged.
        before_tree=snapshot(root)
        try:f.finalize({'root':str(root),'artifact':old,**config['tools'],'readelf':config['tools']['cc']})
        except (ValueError,subprocess.CalledProcessError):assert snapshot(root)==before_tree
        else:raise AssertionError('failed inspector accepted')
        results.append({'control':'failed-ELF-inspector','status':'REJECTED_BEFORE_WRITE'})
    return results


if __name__=='__main__':
    print(json.dumps(main(json.loads(Path(sys.argv[1]).read_text()),Path(sys.argv[2]).resolve()),indent=2))

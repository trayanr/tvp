"""Tiny offline source/copy/native-byte guards. Never runs a packaged program."""
import importlib.util
import json
import os
from pathlib import Path
import shlex
import shutil
import struct
import subprocess
import sys
import tarfile
import tempfile

ROOT=Path(__file__).resolve().parents[2]


def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path)
    module=importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    return module


def reject(call):
    try: call()
    except (ValueError,FileNotFoundError): return
    raise AssertionError('unsafe fixture accepted')


def object_bytes(value, section=b'.rodata', flags=2):
    strings=b'\0.shstrtab\0'+section+b'\0'
    payload=b'\0'+value+b'\0'; offset=64+len(strings); table=(offset+len(payload)+7)//8*8
    header=bytearray(64); header[:7]=b'\x7fELF\x02\x01\x01'
    struct.pack_into('<HHI',header,16,1,62,1)
    struct.pack_into('<Q',header,40,table)
    struct.pack_into('<HHHHHH',header,52,64,0,0,64,3,1)
    sections=bytes(64)+struct.pack('<IIQQQQIIQQ',1,3,0,0,64,len(strings),0,0,1,0)+struct.pack('<IIQQQQIIQQ',11,1,flags,0,offset,len(payload),0,0,1,0)
    return bytes(header)+strings+payload+bytes(table-offset-len(payload))+sections


def interpreter_bytes(value):
    strings=b'\0.shstrtab\0.interp\0'; begin=120+len(strings)
    payload=value+b'\0'; table=(begin+len(payload)+7)//8*8
    header=bytearray(64); header[:7]=b'\x7fELF\x02\x01\x01'
    struct.pack_into('<HHI',header,16,3,62,1)
    struct.pack_into('<Q',header,32,64);struct.pack_into('<Q',header,40,table)
    struct.pack_into('<HHHHHH',header,52,64,56,1,64,3,1)
    program=struct.pack('<IIQQQQQQ',3,4,begin,begin,begin,len(payload),len(payload),1)
    sections=bytes(64)+struct.pack('<IIQQQQIIQQ',1,3,0,0,120,len(strings),0,0,1,0)+struct.pack('<IIQQQQIIQQ',11,1,2,begin,begin,len(payload),0,0,1,0)
    return bytes(header)+program+strings+payload+bytes(table-begin-len(payload))+sections


def archive_bytes(body):
    header=b'member.o/       '+b'0           '+b'0     '+b'0     '+b'100644  '+str(len(body)).encode().ljust(10)+b'`\n'
    assert len(header)==60
    return b'!<arch>\n'+header+body+(b'\n' if len(body)%2 else b'')


def main():
    evaluated=json.loads(Path(sys.argv[1]).read_text())
    readelf=sys.argv[2]
    elf=load('explicit_elf',ROOT/'pkgs/libraries/libxml2/ordinary/elf.py')
    with tempfile.TemporaryDirectory(prefix='final-gnu-jdk-') as tmp:
        work=Path(tmp)
        # Standalone store-file style imports: helpers do not get siblings.
        for name,rel in [('glibc','pkgs/libraries/glibc/native/finalize.py'),
                         ('gcc','pkgs/compilers/gcc/native/checkpoint.py'),
                         ('gcc13','pkgs/compilers/gcc/native/checkpoint-13.3.0.py'),
                         ('gcc_final','pkgs/compilers/gcc/native/finalize.py'),
                         ('gcc_restore','pkgs/compilers/gcc/tests/restore-16.2.0.py'),
                         ('jdk_state','pkgs/runtimes/jdk/native/assembly-state.py'),
                         ('jdk','pkgs/runtimes/jdk/native/assembly.py')]:
            standalone=work/(name+'.py'); shutil.copyfile(ROOT/rel,standalone)
            globals()[name]=load(name,standalone)
        out=work/'glibc-final-output-with-equal-width-prefix'; binroot=work/'glibc-final-bin-with-equal-width-prefix'
        out.mkdir(); binroot.mkdir()
        old=lambda p: '/nix/store/'+'a'*32+'-'+'x'*(len(str(p))-44)
        oldout,oldbin=old(out),old(binroot).replace('a'*32,'b'*32)
        assert len(oldout)==len(str(out)) and len(oldbin)==len(str(binroot))
        mapping=[(oldout.encode(),str(out).encode()),(oldbin.encode(),str(binroot).encode())]
        for suffix in glibc.DEFAULTS:
            assert glibc.slot(oldout.encode()+suffix,*mapping[0],'fixture')==str(out).encode()+suffix
        reject(lambda:glibc.slot(oldout.encode()+b'/unknown',*mapping[0],'fixture'))
        obj=work/'fixture.o'; data=object_bytes(oldout.encode()+b'/lib/locale');obj.write_bytes(data)
        fixed=glibc.native(obj,data,mapping,elf,readelf)
        assert len(fixed)==len(data) and oldout.encode() not in fixed and str(out).encode() in fixed
        interp=interpreter_bytes(oldout.encode()+b'/lib/ld-linux-x86-64.so.2'); obj.write_bytes(interp)
        fixedinterp=glibc.native(obj,interp,mapping,elf,readelf)
        assert len(fixedinterp)==len(interp) and oldout.encode() not in fixedinterp
        malformed=bytearray(interp);struct.pack_into('<Q',malformed,72,1);obj.write_bytes(malformed)
        reject(lambda:glibc.native(obj,bytes(malformed),mapping,elf,readelf))
        ar=archive_bytes(data); fixedar=glibc.archive(ar,mapping,elf,readelf,work)
        assert len(fixedar)==len(ar) and oldout.encode() not in fixedar
        for section,flags in [(b'.data',3),(b'.rodata',3)]:
            bad=object_bytes(oldout.encode()+b'/lib/locale',section,flags);obj.write_bytes(bad)
            reject(lambda:glibc.native(obj,bad,mapping,elf,readelf))
        obj.write_bytes(object_bytes(oldout.encode()+b'/unrecognized'))
        reject(lambda:glibc.native(obj,obj.read_bytes(),mapping,elf,readelf))
        (out/'libexec/getconf').mkdir(parents=True); (out/'lib').mkdir()
        (binroot/'bin').mkdir(); (binroot/'bin/getconf').write_bytes(b'getconf fixture\n')
        for alias in glibc.GETCONF: (out/'libexec/getconf'/alias).write_bytes(b'getconf fixture\n')
        (out/'lib/libc.a').write_bytes(ar)
        (out/'lib/libc.so').write_text('GROUP ( '+oldout+'/lib/libc.so.6 )\n')
        config={'roots':{'out':str(out),'bin':str(binroot)},'artifacts':{'out':oldout,'bin':oldbin},'readelf':readelf,'linuxHeaders':'/nix/store/headers'}
        # A late unknown binary must fail without modifying earlier good data.
        before=(out/'lib/libc.a').read_bytes();(binroot/'late-invalid').write_bytes(oldbin.encode()+b'\0unknown')
        reject(lambda:glibc.finalize(config,str(ROOT/'pkgs/libraries/libxml2/ordinary/elf.py')))
        assert (out/'lib/libc.a').read_bytes()==before
        (binroot/'late-invalid').unlink()
        glibc.finalize(config,str(ROOT/'pkgs/libraries/libxml2/ordinary/elf.py'))
        assert oldout.encode() not in (out/'lib/libc.a').read_bytes()
        assert str(out) in (out/'lib/libc.so').read_text()
        assert all(os.path.samefile(out/'libexec/getconf'/a,binroot/'bin/getconf') for a in glibc.GETCONF)
        # GCC validates a late failure before changing earlier public text.
        gccroot=work/'gcc-public';(gccroot/'lib').mkdir(parents=True)
        (gccroot/'lib/metadata.la').write_text(oldout+'/lib /tvp/gcc/lib\n')
        (gccroot/'lib/late').write_bytes(oldout.encode()+b'\0unknown')
        original=(gccroot/'lib/metadata.la').read_bytes()
        reject(lambda:gcc_final.finalize(str(gccroot),oldout,'/tvp/gcc',readelf,'/explicit/unused-patchelf',str(ROOT/'pkgs/libraries/libxml2/ordinary/elf.py')))
        assert (gccroot/'lib/metadata.la').read_bytes()==original
        (gccroot/'lib/late').unlink()
        gcc_final.finalize(str(gccroot),oldout,'/tvp/gcc',readelf,'/explicit/unused-patchelf',str(ROOT/'pkgs/libraries/libxml2/ordinary/elf.py'))
        assert (gccroot/'lib/metadata.la').read_text()==str(gccroot)+'/lib '+str(gccroot)+'/lib\n'
        # A real selected checkpoint save/restore (small bytes; no make).
        source=work/'checkpoint-source'; source.mkdir()
        for name in ['source/gcc/testsuite/tiny.exp','build/Makefile','build/stage_final','build/gcc/xgcc','build/gcc/cc1','build/gcc/cc1plus','build/stage2-gcc/obsolete.o','build/stage2-start']:
            p=source/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_text('fixture '+str(source)+'\n')
        os.link(source/'build/gcc/cc1',source/'build/gcc/compiler-alias')
        header=source/'source/libstdc++-v3/include/std/algorithm'
        header.parent.mkdir(parents=True);header.write_text('native header fixture\n')
        alias=source/'build/x86_64-unknown-linux-gnu/libstdc++-v3/include/algorithm'
        alias.parent.mkdir(parents=True);alias.symlink_to(header)
        (source/'build/headers').symlink_to(header.parent, target_is_directory=True)
        (source/'build/all-source').symlink_to(source/'source', target_is_directory=True)
        checkpoint=work/'checkpoint';gcc.save(source,checkpoint)
        restored=work/'restoration';restored.mkdir();gcc_restore.restore(checkpoint,restored,work/'gcc.py')
        tree=Path((restored/'tree-path').read_text().strip())
        assert not (tree/'build/stage2-gcc').exists() and (tree/'build/stage2-start').is_file()
        assert os.path.samefile(tree/'build/gcc/cc1',tree/'build/gcc/compiler-alias')
        assert str(tree) in (tree/'build/Makefile').read_text()
        assert alias.is_symlink() and os.path.isabs(os.readlink(alias))
        for rel in ['build/x86_64-unknown-linux-gnu/libstdc++-v3/include/algorithm',
                    'build/headers/algorithm','build/all-source/libstdc++-v3/include/std/algorithm']:
            assert (tree/rel).read_text()=='native header fixture\n'
        assert not os.path.isabs(os.readlink(tree/alias.relative_to(source)))
        checkpoint13=work/'checkpoint13';gcc13.save(source,checkpoint13)
        restored13=work/'restoration13';restored13.mkdir()
        gcc_restore.restore(checkpoint13,restored13,work/'gcc13.py')
        tree13=Path((restored13/'tree-path').read_text().strip())
        assert (tree13/alias.relative_to(source)).read_text()=='native header fixture\n'
        outside=work/'external-header';outside.write_text('outside\n')
        for policy in (gcc,gcc13):
            for i,target in enumerate([outside,source/'build/stage2-gcc/obsolete.o',
                                       str(header)+'/.',source/'source/missing-header']):
                alias.unlink();alias.symlink_to(target)
                rejected=work/('rejected-'+policy.__name__+'-'+str(i))
                reject(lambda:policy.save(source,rejected))
                assert not rejected.exists()
        alias.unlink();alias.symlink_to(header)
        # Execute the actual raw-validation prelude with the runner's readonly
        # root. Stop before make; only a tiny checkpoint and shell wiring run.
        gcc_control=evaluated['gcc_16_2_0']
        artifact=work/'gcc-capture-artifact'
        shutil.copytree(checkpoint,artifact/'nix-support/upstream-build-tree')
        production=artifact/'nix-support/production';production.mkdir()
        (production/'stage-flags.txt').write_text('CFLAGS=-O2\nCXXFLAGS=-O2\n')
        prelude=gcc_control['validationCommand'].split('check_status=0\n',1)[0]
        assert prelude!=gcc_control['validationCommand']
        prelude=prelude.replace(gcc_control['artifact'],str(artifact))
        for broken in (True,False):
            workspace=work/('capture-negative' if broken else 'capture-positive');workspace.mkdir()
            body=prelude
            if broken:
                body=body.replace('checkpoint="$(cat tree-path)"','checkpoint="$(cat tree-path)"\nexport TVP_SOURCE_ROOT="$checkpoint"')
            body+='\ntest "$TVP_SOURCE_ROOT" = "$1"\ntest "${PYTHONPATH%%:*}" = "$checkpoint/source/gcc/testsuite"\nprintf capture-wiring-ok\n'
            result=subprocess.run([shutil.which('bash'),'-euc','readonly TVP_SOURCE_ROOT="$1"\n'+body,'capture-control',str(workspace)],cwd=workspace,env={**os.environ,'out':str(workspace/'result'),'CC':'unused-cc','CXX':'unused-cxx'},capture_output=True,text=True)
            if broken:
                assert result.returncode!=0 and 'readonly variable' in result.stderr
            else:
                assert result.returncode==0,(result.returncode,result.stderr)
                assert result.stdout.endswith('capture-wiring-ok')
        # Actual retained JDK selection, copy and native-byte map, no JDK tool.
        raw=work/'jdk-raw'; build=raw/'build/conf'
        for name in ['make/CreateJmods.gmk','make/Images.gmk','make/common/dummy.gmk','src/java.base/share/classes/module-info.java','src/java.base/share/native/should-not-retain.c','build/conf/spec.gmk','build/conf/jdk/modules/java.base/module-info.class','build/conf/jdk/modules/jdk.jlink/module-info.class','build/conf/jdk/release','build/conf/support/src.zip','build/conf/support/modules_libs/java.base/libnative.so','build/conf/support/modules_cmds/java.base/java']:
            p=raw/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_text('fixture '+str(raw)+'\n')
        (build/'support/modules_libs/java.base/libnative.so').write_bytes(b'\x7fELFnative-library')
        (build/'support/modules_cmds/java.base/java').write_bytes(b'\x7fELFnative-command')
        for name in jdk.RESOURCE_PATHS:
            path=build/'jdk/modules'/name
            path.parent.mkdir(parents=True,exist_ok=True)
            path.write_bytes(b'\x7fELFnative-resource')
        checkpoint=work/'jdk-checkpoint';jdk_state.save(raw,checkpoint,'conf')
        image=work/'raw-image';public=work/'public-image'
        for r in (image,public):
            (r/'lib').mkdir(parents=True);(r/'bin').mkdir()
            (r/'lib/libnative.so').write_bytes(b'\x7fELFnative-library')
            (r/'bin/java').write_bytes(b'\x7fELFnative-command')
        (public/'nix-support').mkdir()
        assembly=work/'assembly';jdk.prepare(checkpoint,public,assembly)
        assert not (assembly/'src/java.base/share/native/should-not-retain.c').exists()
        assert str(assembly) in (assembly/'build/conf/spec.gmk').read_text()
        for name in jdk.RESOURCE_PATHS:
            staged=public/jdk.RESOURCE_STAGE/name
            assert staged.read_bytes()==b'\x7fELFnative-resource'
            staged.write_bytes(b'\x7fELFrepaired-resource')
        (public/'lib/libnative.so').write_bytes(b'\x7fELFrepaired-library')
        jdk.mirror(image,public,assembly,'conf')
        assert (assembly/'build/conf/support/modules_libs/java.base/libnative.so').read_bytes()==(public/'lib/libnative.so').read_bytes()
        assert all((assembly/'build/conf/jdk/modules'/name).read_bytes()==b'\x7fELFrepaired-resource' for name in jdk.RESOURCE_PATHS)
        assert not (public/jdk.RESOURCE_STAGE).exists()
        cmds=jdk.commands('/explicit/make','/explicit/bash',public,assembly,'conf','/explicit/false','selected-image')
        assert cmds[-2][-2:]==['MODULE=java.base','all'] and cmds[-1][-1]=='jdk'
        assert all('Main.gmk' not in ' '.join(c) for c in cmds)
        assert all('JAVAC=/explicit/false' in c and 'CC=/explicit/false' in c for c in cmds)
        # Copy the actual evaluated GCC/JDK public-copy commands below; no
        # production commands or fake marker implementations are run here.
        evaluated=json.loads(Path(sys.argv[1]).read_text())
        for name,step in [('gcc_16_2_0','gcc.copy-public'),('jdk_21_0_13','jdk.copy-raw-image')]:
            artifact=work/(name+'-A'); final=work/(name+'-F')
            (artifact/'bin').mkdir(parents=True);(artifact/'bin/tool').write_bytes(b'copied selected bytes')
            (artifact/'nix-support/assembly').mkdir(parents=True);(artifact/'nix-support/production').mkdir()
            (artifact/'nix-support/source-date-epoch').write_text('123\n')
            (artifact/'nix-support/production/immutable').write_text('raw provenance')
            command=next(s['run'] for s in evaluated[name]['steps'] if s['name']==step)
            subprocess.run([shutil.which('bash'),'-euc',command],env={**os.environ,'out':str(final),'TVP_ARTIFACT_ROOT':str(artifact)},check=True,cwd=work)
            assert (final/'bin/tool').read_bytes()==b'copied selected bytes'
            assert not (final/'nix-support/assembly').exists() and not (final/'nix-support/production').exists()
        # Actual complete named-output copy command, including mode/hardlink data.
        aout=work/'named-A-out';abin=work/'named-A-bin';fout=work/'named-F-out';fbin=work/'named-F-bin'
        aout.mkdir();abin.mkdir();(aout/'data').write_bytes(b'complete-out')
        (abin/'data').write_bytes(b'complete-bin');os.link(aout/'data',aout/'alias')
        command=next(s['run'] for s in evaluated['glibc_2_39']['steps'] if s['name']=='output.copy-artifacts')
        prefix='declare -Ar TVP_ARTIFACT_OUTPUTS=([out]='+shlex.quote(str(aout))+' [bin]='+shlex.quote(str(abin))+');\n'
        subprocess.run([shutil.which('bash'),'-euc',prefix+command],env={**os.environ,'out':str(fout),'bin':str(fbin)},check=True,cwd=work)
        assert (fout/'data').read_bytes()==b'complete-out' and (fbin/'data').read_bytes()==b'complete-bin'
        assert os.path.samefile(fout/'data',fout/'alias')
    print('offline-native-byte-checkpoint-assembly-copy-guards: PASS')


if __name__=='__main__': main()

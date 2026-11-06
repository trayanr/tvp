"""Reproduce exact upstream fixtures; supplemental controls never replace FAILs."""
from pathlib import Path
import json
import os
import subprocess
import sys

m=json.loads(Path(sys.argv[1]).read_text());root=Path(sys.argv[2]);root.mkdir()
os.chdir(root)
env=dict(PATH=m['driver']+'/bin:'+m['binutils']+'/bin:'+m['shell']+'/bin:'+m['coreutils']+'/bin',HOME=str(root),LC_ALL='C',TZ='UTC')
cc=m['driver']+'/bin/gcc';cxx=m['driver']+'/bin/g++';src=Path(m['source'])
gcc=src/'gcc/testsuite';plugin=gcc/'gcc.dg/plugin';records=[]
def run(name,args):
 p=subprocess.run(list(map(str,args)),env=env,text=True,capture_output=True)
 records.append(dict(name=name,args=list(map(str,args)),status=p.returncode,stdout=p.stdout,stderr=p.stderr))
 (root/'commands.json').write_text(json.dumps(records,indent=2)+'\n')
 return p
headers=run('plugin-query',[cc,'-print-file-name=plugin']).stdout.strip()+'/include'
for name in ['crash_test_plugin','analyzer_cpython_plugin']:
 p=run('build-'+name,[cxx,'-shared','-fPIC','-fno-rtti','-I'+headers,'-I'+m['gmp']+'/include',plugin/(name+'.cc'),'-o',name+'.so'])
 assert p.returncode==0,p.stderr
for name in ['crash-test-nested-ice','crash-test-nested-write-through-null']:
 args=[cc,'-O','-fno-report-bug','-fplugin='+str(root/'crash_test_plugin.so'),'-fdiagnostics-add-output=sarif','-fdiagnostics-add-output=experimental-html:javascript=no','-c',plugin/(name+'.c'),'-o',name+'.o']
 nested=run(name,args+['-fplugin-arg-crash_test_plugin-nested'])
 control=run(name+'-unnested-control',args)
 assert nested.returncode!=0 and 'placeholder' in nested.stderr
 assert control.returncode!=0 and 'internal compiler error' in control.stderr
 assert 'during GIMPLE pass: crash_test' not in nested.stderr
python_include=Path(m['python'])/'include/python3.12'
for name in ['PyList_New','PyLong_FromLong']:
 original=plugin/('cpython-plugin-test-'+name+'.c')
 args=[cc,'-fanalyzer','-I'+str(plugin),'-I'+str(python_include),'-fplugin='+str(root/'analyzer_cpython_plugin.so'),'-c']
 p=run('cpython-'+name,[*args,original,'-o',name+'.o']);assert p.returncode==0,p.stderr
 changed=root/(name+'-control.c');changed.write_text(original.read_text().replace('Py_INCREF (p);','p->ob_refcnt++;'))
 control=run('cpython-'+name+'-control',[*args,changed,'-o',name+'-control.o'])
 assert control.returncode==0 and "expected 'p' to have reference count" in control.stderr
 assert "expected 'p' to have reference count" not in p.stderr
p=run('bad-pragma',[cc,'-fdiagnostics-format=sarif-file','-Wpragmas','-c',gcc/'gcc.dg/sarif-output/bad-pragma.c','-o','bad-pragma.o'])
assert p.returncode==0
sarif=list(root.glob('*bad-pragma*.sarif'));assert sarif
payload=sarif[0].read_text();assert 'gcc-16.2.0' in payload or 'gcc-16.2' in payload
for name,options in [('pr115102',['-Os','-march=x86-64','-dp']),('xchg-4',['-O2'])]:
 p=run(name+'-assembly',[cc,*options,'-S',gcc/('gcc.target/i386/'+name+'.c'),'-o',name+'.s']);assert p.returncode==0
text=(root/'pr115102.s').read_text();assert 'bswaphisi2_lowpart' not in text
text=(root/'xchg-4.s').read_text();assert 'rolw' not in text and 'mov' in text
reference=root/'reference.c';reference.write_text(r'''
#include <stdint.h>
#include <string.h>
unsigned int bswap8(unsigned int); void foo(int);unsigned int got;
void ext(int n){got=(unsigned int)n;}
int main(){unsigned hi[]={0,1,0x1234,0x8000,0xffff};
for(int k=0;k<5;k++)for(unsigned lo=0;lo<65536;lo++){
uint32_t n=(hi[k]<<16)|lo,ref;unsigned char bytes[4];memcpy(bytes,&n,4);
unsigned char b=bytes[0];bytes[0]=bytes[1];bytes[1]=b;memcpy(&ref,bytes,4);
if(bswap8(n)!=ref)return 1;foo((int)n);if(got!=ref)return 2;}return 0;}
''')
for opt in ['-O2','-Os']:
 p=run('codegen-control-'+opt,[cc,opt,gcc/'gcc.target/i386/pr115102.c',gcc/'gcc.target/i386/xchg-4.c',reference,'-o','reference']);assert p.returncode==0
 assert run('codegen-run-'+opt,[root/'reference']).returncode==0
resolver=src/'libstdc++-v3/testsuite/experimental/net/internet/resolver/ops/lookup.cc'
p=run('resolver-build',[cxx,'-std=gnu++20','-pthread','-I'+str(src/'libstdc++-v3/testsuite/util'),resolver,'-o','resolver'])
assert p.returncode==0,p.stderr
p=run('resolver-outside-sandbox',[root/'resolver']);assert p.returncode==0,p.stderr
(root/'summary.json').write_text(json.dumps(dict(exactFixtures=True,releaseICEPolicy=True,cpythonSplitRefcountControl=True,versionedSARIFURL=True,codegenControlInputsPerFunctionPerOptimization=327680,resolverOutsideSandboxStatus=p.returncode,rawUnexpectedOutcomesUnchanged=True),indent=2)+'\n')

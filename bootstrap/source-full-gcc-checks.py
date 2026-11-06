"""Installed full compiler capabilities; raw upstream failures remain separate."""
import collections
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

out, evidence = map(Path, sys.argv[1:3]); m=json.loads(sys.argv[3])
out.mkdir();evidence.mkdir(exist_ok=True)
work=Path.cwd(); cc=m['driver']+'/bin/gcc';cxx=m['driver']+'/bin/g++'
raw=Path(m['compiler']); tools=m['binutils']+'/bin/'
env=dict(PATH=m['driver']+'/bin:'+m['binutils']+'/bin:'+m['shell']+'/bin:'+m['coreutils']+'/bin',HOME=str(work/'home'),LC_ALL='C',TZ='UTC')
Path(env['HOME']).mkdir()
commands=[]
def run(name,args,expected=0,extra=None):
    p=subprocess.run(list(map(str,args)),text=True,capture_output=True,env=env|(extra or {}))
    record=dict(name=name,args=list(map(str,args)),status=p.returncode,stdout=p.stdout,stderr=p.stderr)
    commands.append(record);(evidence/'commands.json').write_text(json.dumps(commands,indent=2)+'\n')
    if expected != 'any':
        assert p.returncode==expected if expected is not None else p.returncode!=0,(name,p.returncode,p.stderr)
    return p

def fixture(name,text):
    p=work/name;p.write_text(text);return str(p)
def build(name,source,flags=(),cpp=False):
    src=fixture(name+('.cc' if cpp else '.c'),source)
    compile_flags=[f for f in flags if not f.startswith('-l')]; libraries=[f for f in flags if f.startswith('-l')]
    run(name+'-build',[cxx if cpp else cc,*compile_flags,src,*libraries,'-o',work/name]);return str(work/name)
def loaded(name,exe,providers):
    p=run(name,[exe],extra={'LD_DEBUG':'libs'})
    actual=re.findall(r'calling init: (/\S+)',p.stderr)
    for lib in providers:
        assert any(path.startswith(m['compiler']+'/') and lib in path for path in actual),(lib,actual)
    assert not any('/usr/' in path or path.startswith('/lib/') for path in actual)
    return p

previous=json.loads((Path(m['previousEvidence'])/'summary.json').read_text());assert previous['result']=='PASS'
run('version',[cc,'--version'])
for name in ['cc1','cc1plus','collect2','lto1','lto-wrapper']:
    p=run('query-'+name,[cc,'-print-prog-name='+name]).stdout.strip();assert p.startswith(m['compiler']+'/') and Path(p).exists(),(name,p)
for name in ['cc1','cc1plus','collect2','lto1','lto-wrapper']:
    path=run('host-query-'+name,[cc,'-print-prog-name='+name]).stdout.strip()
    run('host-elf-'+name,[tools+'readelf','-W','-l','-d',path])
    p=run('host-providers-'+name,[m['libc']+'/lib/ld-linux-x86-64.so.2','--list',path])
    assert not re.search(r'=> /(?:usr|lib)/',p.stdout)
    if name in ['cc1','cc1plus','lto1']:
        assert m['zlib']+'/lib/' in p.stdout and m['zstd']+'/lib/' in p.stdout
for name in ['libgcc.a','libgcc_s.so.1','libstdc++.so','libgomp.so','libatomic.so','libitm.so','libquadmath.so','libasan.so','libubsan.so','libtsan.so','liblsan.so']:
    p=run('query-'+name,[cc,'-print-file-name='+name]).stdout.strip();assert p.startswith(m['compiler']+'/') or p.startswith(m['driver']+'/'),(name,p)
    assert Path(p).exists(),p
rt=build('runtime',r'''
#include <iostream>
#include <fstream>
#include <vector>
#include <thread>
#include <stdexcept>
#include <dlfcn.h>
struct A {virtual ~A()=default;}; struct B:A{};
int main(){B b; A& a=b; if(!dynamic_cast<B*>(&a))return 1;
std::vector<int> x{40};std::thread t([&]{x[0]+=2;});t.join();
try {throw std::runtime_error("owned");}catch(const std::exception&){}
void* h=dlopen("libstdc++.so.6",RTLD_NOW);if(!h)return 3;
Dl_info info{};if(!dladdr(dlsym(h,"__cxa_throw"),&info))return 2;
std::cout<<x[0]<<"\n"<<info.dli_fname<<"\n";
std::ifstream maps("/proc/self/maps");std::cout<<maps.rdbuf();
}
'''.replace('#include <dlfcn.h>','#include <dlfcn.h>\n#include <cxxabi.h>\nusing __cxxabiv1::__cxa_throw;'),['-std=c++20','-pthread','-ldl'],True)
p=loaded('runtime',rt,['libstdc++','libgcc_s']);assert p.stdout.splitlines()[0]=='42' and m['compiler']+'/' in p.stdout
# Distinct source objects and an archive require actual linker-plugin loading.
a=fixture('lto-a.c','int answer(void){return 42;}\n');b=fixture('lto-b.c','extern int answer(void);int main(void){return answer()!=42;}\n')
run('lto-a',[cc,'-flto','-c',a,'-o','a.o']);run('lto-b',[cc,'-flto','-c',b,'-o','b.o'])
for name,args in [('ar',['rcs','answer.a','a.o']),('ranlib',['answer.a']),('nm',['answer.a'])]:
    run('gcc-'+name,[raw/'bin'/('gcc-'+name),*args])
run('lto-link',[cc,'-v','-flto','b.o','answer.a','-o','lto']);run('lto-run',[work/'lto'])
assert 'liblto_plugin.so' in commands[-2]['stderr'] and 'lto-wrapper' in commands[-2]['stderr']
graphite=build('graphite',r'''
#include <stdio.h>
int a[128][128];int main(){for(int i=0;i<128;i++)for(int j=0;j<128;j++)a[i][j]=i+j;
long n=0;for(int i=0;i<128;i++)for(int j=0;j<128;j++)n+=a[i][j];printf("%ld\n",n);return n!=2080768;}
''',['-O2','-fgraphite-identity','-floop-nest-optimize','-fdump-tree-graphite-details'])
run('graphite', [graphite]);assert any(re.search(r'number of SCoPs: [1-9]',p.read_text()) for p in work.glob('*.graphite'))
plugin=fixture('plugin.cc',r'''
#include "gcc-plugin.h"
#include "plugin-version.h"
int plugin_is_GPL_compatible;
int plugin_init(struct plugin_name_args*,struct plugin_gcc_version* v){return !plugin_default_version_check(v,&gcc_version);}
''')
plugin_dir=run('plugin-dir',[cc,'-print-file-name=plugin']).stdout.strip();assert plugin_dir.startswith(m['compiler']+'/')
run('plugin-build',[cxx,'-shared','-fPIC','-fno-rtti','-I'+plugin_dir+'/include','-I'+m['gmp']+'/include',plugin,'-o','owned-plugin.so'])
hello=fixture('hello.c','#include <stdio.h>\nint main(){puts("42");return 0;}\n')
run('plugin-load',[cc,'-fplugin='+str(work/'owned-plugin.so'),'-c',hello,'-o','plugin.o'])
bad=fixture('analyzer.c','int f(void){int *p=0;return *p;}\n')
p=run('analyzer',[cc,'-fanalyzer','-c',bad,'-o','analyzer.o']);assert '-Wanalyzer-null-dereference' in p.stderr
omp=build('openmp','#include <omp.h>\nint main(){int n=0;\n#pragma omp parallel reduction(+:n)\nn+=1;return n<2;}\n',['-fopenmp'])
loaded('openmp',omp,['libgomp'])
atomic=build('atomic','_Atomic(__int128) n;int main(){__int128 x=42;__atomic_store_n((__int128*)&n,x,5);return __atomic_load_n((__int128*)&n,5)!=42;}\n',['-latomic'])
loaded('atomic',atomic,['libatomic'])
itm=build('itm','int n;int main(){__transaction_atomic{n=42;}return n!=42;}\n',['-fgnu-tm'])
loaded('itm',itm,['libitm'])
quad=build('quadmath','#include <quadmath.h>\nint main(){volatile __float128 x=1764.0Q;return sqrtq(x)!=42.0Q;}\n',['-lquadmath'])
loaded('quadmath',quad,['libquadmath'])
san=build('sanitizers',Path(hello).read_text(),['-fsanitize=address,undefined'])
loaded('sanitizers',san,['libasan','libubsan'])
asan=build('asan-bad','int main(){volatile int i=2;int a[1];return a[i];}\n',['-fsanitize=address','-g'])
p=run('asan-negative',[asan],expected=None);assert 'AddressSanitizer' in p.stderr and 'stack-buffer-overflow' in p.stderr
ubsan=build('ubsan-bad','int main(){volatile int n=2147483647;return n+1;}\n',['-fsanitize=undefined','-fno-sanitize-recover=all'])
p=run('ubsan-negative',[ubsan],expected=None);assert 'runtime error: signed integer overflow' in p.stderr
sanitizers={}
for name in ['thread','leak']:
    exe=build('sanitizer-'+name,Path(hello).read_text(),['-fsanitize='+name])
    p=loaded('sanitizer-'+name,exe,['libtsan' if name=='thread' else 'liblsan'])
    assert p.stdout=='42\n',(name,p.stdout,p.stderr)
    sanitizers[name]=dict(status=p.returncode,stdout=p.stdout,stderr=p.stderr)
p=run('sanitizer-hwaddress-scope',[cc,'-fsanitize=hwaddress',hello,'-o','hwaddress'])
sanitizers['hwaddress']=dict(compilerStatus=p.returncode,compilerDiagnostic=p.stderr)
execution=run('sanitizer-hwaddress-run',[work/'hwaddress'],expected='any',extra={'LD_DEBUG':'libs'})
sanitizers['hwaddress'].update(runtimeStatus=execution.returncode,runtimeDiagnostic=execution.stderr)
assert m['compiler']+'/lib/libhwasan.so' in execution.stderr
if execution.returncode==0:
    assert execution.stdout=='42\n'
else:
    assert execution.returncode==99 and 'FATAL: HWAddressSanitizer requires a kernel with tagged address ABI.' in execution.stderr,execution.stderr

# Real assembler/linker selection: sentinel forwarding wrappers retain invocations.
sentinels=work/'sentinels';sentinels.mkdir()
for name in ['as','ld']:
    p=sentinels/name;p.write_text('#!'+m['shell']+'/bin/bash\nprintf "%s\\n" "'+name+' $*" >> '+str(evidence/'binutils-execution.txt')+'\nexec '+tools+name+' "$@"\n');p.chmod(0o755)
run('binutils-selected',[cc,'-B'+str(sentinels)+'/',hello,'-o','selected']);run('binutils-selected-run',[work/'selected'])
trace=(evidence/'binutils-execution.txt').read_text();assert 'as ' in trace and 'ld ' in trace
response_source=fixture('hello source.c',Path(hello).read_text())
response=fixture('args.rsp','-O1 "'+response_source+'" -o response\n');run('response',[cc,'@'+response]);run('response-run',[work/'response'])
for mode in ['-m16','-m32','-mx32','-static-pie','-mmusl']:
    p=run('reject-'+mode,[cc,mode,'-c',hello],expected=64);assert 'unsupported' in p.stderr
p=run('no-includes',[cc,'-nostdinc','-E',hello],expected=None);assert 'stdio.h' in p.stderr
cppsrc=fixture('no-cxx.cc','#include <vector>\n');run('no-cxx-includes',[cxx,'-nostdinc++','-E',cppsrc],expected=None)
empty=fixture('empty.c','int main(){return 0;}\n')
for flag in ['-nostdlib','-nodefaultlibs','-nostartfiles']:
    p=run('suppress-'+flag,[cc,flag,'-###',empty])
    if flag in {'-nostdlib','-nostartfiles'}:assert 'crt1.o' not in p.stderr
    if flag in {'-nostdlib','-nodefaultlibs'}:
        assert not re.search(r'(?:^|\s)"?-l(?:c|gcc(?:_s|_eh)?|stdc\+\+)"?(?:\s|$)',p.stderr)
    if flag=='-nodefaultlibs':assert 'crt1.o' in p.stderr
for operand in ['-m32','-static-pie']:
    run('operand-'+operand,[cc,'-I',operand,'-c',empty,'-o','operand.o'])
custom=fixture('custom.c','int main(){return TVP_CUSTOMIZATION!=42;}\n')
run('environment-compile',[cc,custom,'-o','custom'],extra={'NIX_CFLAGS_COMPILE':'-DTVP_CUSTOMIZATION=42'})
run('environment-run',[work/'custom'])
exported=build('rdynamic','#include <dlfcn.h>\nint exported=42;int main(){void* h=dlopen(0,RTLD_NOW);return !h || !dlsym(h,"exported");}\n',['-rdynamic','-ldl'])
run('rdynamic-run',[exported])
run('pie',[cc,'-fPIE','-pie',empty,'-o','pie']);run('pie-run',[work/'pie'])
p=run('pie-type',[tools+'readelf','-h','pie']);assert 'DYN' in p.stdout
run('shared',[cc,'-shared','-fPIC',empty,'-o','shared.so'])
run('static',[cc,'-static',empty,'-o','static']);run('static-run',[work/'static'])
for var in ['GCC_EXEC_PREFIX','COMPILER_PATH']:
    p=run('pollution-'+var,[cc,'-E','-v','-xc','/dev/null'],extra={var:'/usr/local/foreign/'})
    assert not re.search(r'^ /(?:usr|lib)(?:/|$)',p.stderr,re.M)
p=run('include-search',[cc,'-E','-v','-xc','/dev/null']);assert not re.search(r'^ /(?:usr|lib)(?:/|$)',p.stderr,re.M)
for exe in [rt,str(work/'lto'),san]:
    p=run('elf-'+Path(exe).name,[tools+'readelf','-W','-l','-d',exe]);assert m['libc']+'/lib/ld-linux-x86-64.so.2' in p.stdout
summary=dict(result='PASS',capabilities=['C++20/STL/exceptions/RTTI/threads/dlopen','archive LTO','Graphite SCoPs','plugin','analyzer','OpenMP','libatomic','libitm','quadmath','ASan/UBSan','driver controls'],otherSanitizers=sanitizers,previousGraphvizRequired=True,strictUpstreamConformance=False)
(evidence/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');(out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')

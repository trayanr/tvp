"""Installed compressed Meson, real dependency methods and pinned source units."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import time
import zipfile

out, evidence = map(Path, sys.argv[1:3]); c = json.loads(sys.argv[3])
(evidence/'selection.json').write_text(json.dumps(c,indent=2))
assert all(c['contracts'].values())

def run(name, args, cwd=None, env=None, ok=True):
    p = subprocess.run(list(map(str,args)),cwd=cwd,env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=180)
    (evidence/(name+'.log')).write_text(p.stdout)
    (evidence/(name+'.status')).write_text(str(p.returncode)+'\n')
    if ok and p.returncode: raise RuntimeError(name+': '+p.stdout)
    return p

meson = c['meson']
assert run('version-env-i',[meson,'--version'],env={}).stdout.strip()=='1.12.1'
with zipfile.ZipFile(c['zipapp']) as z:
    assert len(z.infolist())>100
    assert all(i.compress_type==zipfile.ZIP_DEFLATED for i in z.infolist() if not i.is_dir())
    (evidence/'zipapp.json').write_text(json.dumps(dict(members=len(z.infolist()),compression='ZIP_DEFLATED',interpreter=Path(c['zipapp']).read_bytes().split(b'\n',1)[0].decode())))
source=Path('project');source.mkdir()
for name in ['meson.build','answer.c','main.cc']: shutil.copyfile(Path(c['fixture'])/name,source/name)
buildfile=source/'meson.build'
# Reserve the final prefix in the build RPATH too. The store-preserving
# depfixer retains immutable dependencies, so they must fit alongside it.
text=buildfile.read_text();text=text.replace('install_rpath:', 'build_rpath: join_paths(get_option(\'prefix\'), get_option(\'libdir\')), install_rpath:')
buildfile.write_text(text)
(source/'marker.h').write_text('#define MARKER 1\n')
a=source/'answer.c'; a.write_text('#include "marker.h"\n'+a.read_text())
(source/'meson.options').write_text("option('proof',type:'boolean',value:false)\n")
run('setup',[meson,'setup','build',source,'--prefix='+str(out),'--libdir=lib','--wrap-mode=nodownload','--buildtype=release'])
log=Path('build/meson-logs/meson-log.txt').read_text()
assert c['zlib']+'/lib' in log and c['zlib']+'/include' in log
assert c['pkgConfig'] in log and c['cmake'] in log
(evidence/'discovery.log').write_text(log)
run('compile',[meson,'compile','-C','build','-j',os.environ['NIX_BUILD_CORES']])
p=run('test',[meson,'test','-C','build','--print-errorlogs']);assert 'Ok:                2' in p.stdout
info=json.loads(run('introspect',[meson,'introspect','--targets','build']).stdout)
assert {t['type'] for t in info}>={'shared library','static library','executable'}
objects=sorted(Path('build').rglob('*.o'));assert len(objects)>=4
before=[p.stat().st_mtime_ns for p in objects]
run('noop',[meson,'compile','-C','build']);assert [p.stat().st_mtime_ns for p in objects]==before
time.sleep(1.1);(source/'marker.h').write_text('#define MARKER 2\n')
run('header-rebuild',[meson,'compile','-C','build']);after=[p.stat().st_mtime_ns for p in objects];assert sum(x>y for x,y in zip(after,before))==2
before=after;time.sleep(1.1);a.write_text(a.read_text()+'\n/* source rebuild */\n')
run('source-rebuild',[meson,'compile','-C','build']);assert sum(p.stat().st_mtime_ns>t for p,t in zip(objects,before))==2
run('reconfigure',[meson,'setup','--reconfigure','build',source,'-Dproof=true'])
opts=json.loads(run('options',[meson,'introspect','--buildoptions','build']).stdout);assert next(o for o in opts if o['name']=='proof')['value'] is True
run('install',[meson,'install','-C','build','--no-rebuild'])
assert run('installed-env-i',[out/'bin/answer'],env={}).stdout.strip()=='42'
run('installed-loader',[out/'bin/answer'],env={'LD_DEBUG':'libs'})
a.write_text(a.read_text()+'\n#error expected_failure_probe\n')
assert run('expected-failure',[meson,'compile','-C','build'],ok=False).returncode!=0
# Launcher preserves explicit variables; all three selected overrides really run.
shutil.copytree(source,'override-source');p=Path('override-source/answer.c');p.write_text(p.read_text().replace('#error expected_failure_probe',''))
env=dict(os.environ,NINJA=c['traced']+'/bin/ninja',CMAKE=c['traced']+'/bin/cmake',PKG_CONFIG=c['traced']+'/bin/pkg-config',SHELL=c['shell'],TOOL_TRACE=str((evidence/'tool-trace.log').resolve()))
run('override-setup',[c['selectedMeson'],'setup','override-build','override-source','--wrap-mode=nodownload'],env=env)
run('override-compile',[c['selectedMeson'],'compile','-C','override-build'],env=env)
run('override-test',[c['selectedMeson'],'test','-C','override-build'],env=env)
defaults={k:v for k,v in env.items() if k not in ['NINJA','CMAKE','PKG_CONFIG','SHELL']}
run('defaults-override-setup',[c['selectedMeson'],'setup','defaults-override-build','override-source','--wrap-mode=nodownload'],env=defaults)
run('defaults-override-compile',[c['selectedMeson'],'compile','-C','defaults-override-build'],env=defaults)
trace=(evidence/'tool-trace.log').read_text();assert all(x+' ' in trace for x in ['ninja','cmake','pkg-config'])
# Keep .tar.xz fixture: no download or uncompressed workaround.
shutil.copytree(Path(c['fixture'])/'wrap','wrap-project')
for p in Path('wrap-project').rglob('*'): p.chmod(p.stat().st_mode | 0o200)
Path('wrap-project').chmod(0o755)
w=Path('wrap-project');cache=w/'subprojects/packagecache';cache.mkdir(parents=True)
archive=cache/'child.tar.xz'
with tarfile.open(archive,'w:xz') as t: t.add(w/'child',arcname='child')
digest=hashlib.sha256(archive.read_bytes()).hexdigest()
(w/'subprojects/child.wrap').write_text('[wrap-file]\ndirectory = child\nsource_filename = child.tar.xz\nsource_url = https://invalid.example/child.tar.xz\nsource_hash = '+digest+'\n')
shutil.rmtree(w/'child')
run('wrap-setup',[meson,'setup','wrap-build',w,'--wrap-mode=nodownload'])
run('wrap-compile',[meson,'compile','-C','wrap-build'])
run('wrap-test',[meson,'test','-C','wrap-build','--print-errorlogs'])
assert run('wrap-answer',[Path('wrap-build/answer').resolve()],env={}).stdout.strip()=='42'
(evidence/'wrap.json').write_text(json.dumps(dict(sha256=digest,compression='xz',mode='nodownload')))
# Preserve upstream _pathlib injection, and record source versus zip imports.
with tarfile.open(c['source']) as t: t.extractall('upstream',filter='data')
upstream=Path('upstream/meson-1.12.1').resolve()
runner=Path('unit-subset.py');runner.write_text('''import sys,unittest,json
source,zipapp,mode=sys.argv[1:]
sys.path.insert(0, source)
if mode=='installed': sys.path.insert(0,zipapp)
import mesonbuild._pathlib
sys.modules['pathlib']=mesonbuild._pathlib
import mesonbuild.coredata
names=['test_version_number','test_version_compare','test_split_args','test_quote_arg','test_depfile','test_listify','test_string_templates_substitution','test_option_key_from_string']
suite=unittest.TestLoader().loadTestsFromNames(['unittests.internaltests.InternalTests.'+n for n in names])
r=unittest.TextTestRunner(verbosity=2).run(suite)
print('TVP_RESULT='+json.dumps(dict(tests=r.testsRun,failures=len(r.failures),errors=len(r.errors),skips=len(r.skipped),core=mesonbuild.coredata.__file__,pathlib=mesonbuild._pathlib.__file__)))
raise SystemExit(not r.wasSuccessful())
''')
units={}
for mode in ['source','installed']:
    p=run('upstream-'+mode,[c['python'],runner,upstream,c['zipapp'],mode])
    result=json.loads(next(l.split('=',1)[1] for l in p.stdout.splitlines() if l.startswith('TVP_RESULT=')))
    assert result['tests']==8 and result['errors']==result['failures']==0
    assert (c['zipapp'] in result['core'])==(mode=='installed')
    units[mode]=result
(evidence/'summary.json').write_text(json.dumps(dict(units=units,dependencyMethods=['pkg-config','cmake'],tests=2,wrapXZ=True,overrides=True),indent=2))

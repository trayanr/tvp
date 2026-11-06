"""Installed, offline GCC pytest/SARIF proofs and bounded upstream suites."""
import importlib.util
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tarfile
import xml.etree.ElementTree as ET

out, evidence = map(Path, sys.argv[1:3]); f=json.loads(sys.argv[3])
out.mkdir(parents=True); evidence.mkdir(parents=True)
spec=importlib.util.spec_from_file_location('results',sys.argv[4]);results=importlib.util.module_from_spec(spec);spec.loader.exec_module(results)
records=[]; summaries={}
clean=dict(PATH=':'.join(f[n]+'/bin' for n in ['profile','compiler','coreutils','shell']),
           HOME=str(Path.cwd()), TZ='UTC', PYTHONDONTWRITEBYTECODE='1', PYTEST_DISABLE_PLUGIN_AUTOLOAD='1')
python=f['profile']+'/bin/python3'; cli=f['profile']+'/bin/check-jsonschema'

def run(name,args,expected=0,env=None,cwd=None,data=None):
    p=subprocess.run(list(map(str,args)),env=clean if env is None else env,cwd=cwd,input=data,
                     text=True,capture_output=True,timeout=180)
    record=dict(name=name,args=list(map(str,args)),status=p.returncode,stdout=p.stdout,stderr=p.stderr)
    records.append(record)
    (evidence/'commands.json').write_text(json.dumps(records,indent=2)+'\n')
    for suffix,value in [('stdout',p.stdout),('stderr',p.stderr),('status',str(p.returncode)+'\n')]:
        (evidence/(name+'.'+suffix)).write_text(value)
    assert p.returncode==expected, record
    return p

def dump(name,data):
    p=Path(name);p.write_text(json.dumps(data)+'\n');return p.resolve()

def pytest(name,args,expected=0,env=None):
    report=evidence/(name+'.xml')
    p=run(name,[python,'-m','pytest','--color=no','-rap','-s','--tb=no','--junitxml='+str(report),*args],expected,env)
    counts=results.inspect(p.stdout,report,p.returncode)
    assert counts['passed']>0 or expected!=0
    summaries[name]=counts
    return p

assert run('pytest-version',[python,'-m','pytest','--color=no','-rap','-s','--tb=no','--version'],env={}).stdout.strip()=='pytest 8.3.2'
assert '0.23.3' in run('cli-version',[cli,'--version'],env={}).stdout
# Prove installed metadata, data files, explicit dependencies and provider roots.
probe=Path('providers.py')
probe.write_text('''import importlib, importlib.metadata as md, json, pathlib, sys
from packaging.requirements import Requirement
from packaging.utils import canonicalize_name
roots=json.loads(sys.argv[1]); records={}
for name,root in roots.items():
 d=md.distribution(name)
 assert str(d._path).startswith(root+'/'), (name,str(d._path))
 for requirement in d.requires or []:
  r=Requirement(requirement)
  if r.marker is None or r.marker.evaluate({'extra':''}):
   assert md.version(r.name) in r.specifier, (name,requirement)
 build=json.loads(pathlib.Path(root,'share/source-python/build.json').read_text())
 for requirement in build['declaredBuildRequirements']:
  r=Requirement(requirement)
  if r.marker is None or r.marker.evaluate({'extra':''}):
   assert md.version(r.name) in r.specifier, (name,'build',requirement)
 records[name]={'build':build,'version':d.version,'metadata':str(d._path),'requires':d.requires,'files':len(d.files or [])}
for module in ['pytest','jsonschema','pyrsistent','ruamel.yaml','check_jsonschema','requests','yaml']:
 try: m=importlib.import_module(module)
 except ModuleNotFoundError:
  assert module=='yaml'; continue
 assert any(str(m.__file__).startswith(p+'/') for p in roots.values()), m.__file__
from importlib.resources import files
assert files('jsonschema').joinpath('schemas/draft2020-12.json').is_file()
assert list(files('check_jsonschema').joinpath('builtin_schemas').iterdir())
import ruamel.yaml, pyrsistent
assert ruamel.yaml.YAML(typ='safe',pure=True).load('a: 1')=={'a':1}
assert pyrsistent.pvector([1,2]).append(3)==pyrsistent.pvector([1,2,3])
print(json.dumps({'distributions':records,'sysPath':sys.path,'python':sys.executable,'maps':pathlib.Path('/proc/self/maps').read_text()}))
''')
# Build/test backends have their own explicit closure, separate from production.
allpaths=':'.join(p+'/lib/python3.12/site-packages' for p in f['packages'].values())
providers=run('providers',[f['python']+'/bin/python3','-s',probe,json.dumps(f['packages'])],env=dict(clean,PYTHONPATH=allpaths,LD_DEBUG='libs'))
(evidence/'providers.json').write_text(providers.stdout)
# A missing module never falls through to a host installation.
run('missing-dependency',[f['python']+'/bin/python3','-I','-c','import jsonschema'],expected=1,env={})
run('missing-command',[f['shell']+'/bin/bash','-c','check-jsonschema --version'],expected=127,env={'PATH':'/nonexistent'})
# Actual GCC schemas: local internal refs only; the sandbox has no network.
gcc=Path(f['gccSource'])/'gcc/testsuite'; lib=gcc/'lib'
for version,schema in [('2.1','sarif-schema-2.1.0.json'),('2.2','sarif-schema-2.2-prerelease-2024-08-08.json')]:
    doc={'version':('2.1.0' if version=='2.1' else '2.2'),'runs':[{'tool':{'driver':{'name':'owned-test'}},'results':[]}]}
    good=dump('sarif-'+version+'.json',doc)
    run('sarif-'+version+'-valid',[cli,'--schemafile',lib/schema,good],env={})
    doc['runs'][0]['tool']['driver']['name']=23
    bad=dump('sarif-'+version+'-bad.json',doc)
    p=run('sarif-'+version+'-invalid',[cli,'--schemafile',lib/schema,bad],expected=1,env={})
    assert 'name' in p.stdout and ('type' in p.stdout or 'string' in p.stdout)
# New-draft semantics must actually execute (prefixItems, dependentRequired,
# unevaluatedProperties); the Draft04 exclusiveMinimum boolean is also tested.
for name,schema,valid,invalid in [
 ('draft04',{'$schema':'http://json-schema.org/draft-04/schema#','type':'number','minimum':2,'exclusiveMinimum':True},3,2),
 ('draft2020',{'$schema':'https://json-schema.org/draft/2020-12/schema','type':'object','properties':{'a':{'type':'array','prefixItems':[{'const':1}],'items':False},'b':{'type':'integer'}},'dependentRequired':{'a':['b']},'unevaluatedProperties':False},{'a':[1],'b':2},{'a':[2],'extra':1})]:
    s=dump(name+'-schema.json',schema)
    run(name+'-valid',[cli,'--schemafile',s,dump(name+'-good.json',valid)],env={})
    p=run(name+'-invalid',[cli,'--schemafile',s,dump(name+'-bad.json',invalid)],expected=1,env={})
    assert 'Validation' in p.stdout or 'validation' in p.stdout
for label,doc in [('prefix',{'a':[2],'b':2}),('dependency',{'a':[1]}),('unevaluated',{'b':2,'extra':1})]:
    run('draft2020-'+label,[cli,'--schemafile',s,dump('new-draft-'+label+'.json',doc)],expected=1,env={})
malformed=dump('malformed-schema.json',{'$schema':'https://json-schema.org/draft/2020-12/schema','type':42})
p=run('malformed-schema',[cli,'--schemafile',malformed,good],expected=1,env={})
assert 'SchemaError' in p.stdout+p.stderr or 'schema' in p.stdout+p.stderr
# Local format dependencies retain SARIF date-time and URI validation.
s=dump('format-schema.json',{'type':'string','format':'date-time'})
run('format-invalid',[cli,'--schemafile',s,dump('bad-date.json','not-a-date')],expected=1,env={})
# Native compiler output, genuine GCC Python test, then real GCC Expect parser.
source=gcc/'gcc.dg/sarif-output/no-diagnostics.c'
shutil.copyfile(source,'no-diagnostics.c')
run('gcc-sarif',[f['compiler']+'/bin/cc','-fdiagnostics-format=sarif-file','-c','no-diagnostics.c','-o','no-diagnostics.o'])
actual=Path('no-diagnostics.c.sarif').resolve()
run('gcc-sarif-validate',[cli,'--schemafile',lib/'sarif-schema-2.1.0.json',actual])
gccenv=dict(clean,PYTHONPATH=str(lib),SARIF_PATH=str(Path('no-diagnostics.c').resolve()))
pytest('gcc-pytest',[gcc/'gcc.dg/sarif-output/no-diagnostics.py'],env=gccenv)
for stem,options,status in [('missing-semicolon',[],1),('extra-semicolon',['-Wpedantic'],0),('werror',['-Werror=unused-variable'],1)]:
    shutil.copyfile(gcc/('gcc.dg/sarif-output/'+stem+'.c'),stem+'.c')
    run('gcc-'+stem,[f['compiler']+'/bin/cc','-fdiagnostics-format=sarif-file',*options,'-c',stem+'.c','-o',stem+'.o'],expected=status)
    run('schema-'+stem,[cli,'--schemafile',lib/'sarif-schema-2.1.0.json',stem+'.c.sarif'])
    pytest('gcc-'+stem+'-pytest',[gcc/('gcc.dg/sarif-output/'+stem+'.py')],env=dict(gccenv,SARIF_PATH=str(Path(stem+'.c').resolve())))
Path('failed-test.py').write_text('def test_failure_control():\n    assert 1 == 2\n')
pytest('pytest-failure',['failed-test.py'],expected=1)
Path('error-test.py').write_text('import absent_owned_dependency_control\n')
pytest('pytest-error',['error-test.py'],expected=2)
# Exercise the exact unmodified run-sarif-pytest procedure with Expect/PTY.
# Its pass/fail callbacks are supplied by the bounded driver here.
script=Path('gcc-pytest.exp'); script.write_text('''set srcdir $env(GCC_TESTSUITE)
set subdir gcc.dg/sarif-output
proc verbose {args} {}
proc remote_download {where file} {return $file}
proc check_effective_target_pytest3 {} {return 1}
proc setenv {name value} {set ::env($name) $value}
proc getenv {name} {return $::env($name)}
proc pass {args} {puts "GCC-PASS: $args"; incr ::passed}
proc fail {args} {puts "GCC-FAIL: $args"; incr ::failed}
proc unsupported {args} {error "unexpected unsupported: $args"}
set passed 0
set failed 0
source $srcdir/lib/scansarif.exp
run-sarif-pytest $env(SARIF_PATH) no-diagnostics.py
puts "GCC-COUNTS: $passed $failed"
if {$passed != 3 || $failed != 0} {exit 1}
set srcdir [pwd]
set subdir .
run-sarif-pytest $env(SARIF_PATH) failed-test.py
run-sarif-pytest $env(SARIF_PATH) error-test.py
puts "GCC-CONTROL-COUNTS: $passed $failed"
if {$passed != 3 || $failed != 2} {exit 1}
''')
p=run('gcc-expect-pytest',[f['expect']+'/bin/expect',script],env=dict(gccenv,GCC_TESTSUITE=str(gcc)))
assert 'GCC-COUNTS: 3 0' in p.stdout
# Bounded upstream tests use the installed packages, not source-path rescue.
def unpack(name):
    dest=Path(name+'-upstream');dest.mkdir()
    with tarfile.open(f['sources'][name]) as t:t.extractall(dest,filter='data')
    return next(dest.iterdir()).resolve()
pysrc=unpack('pytest')
pytest('upstream-pytest',['-o','addopts=','-p','pytester',pysrc/'testing/test_assertion.py',pysrc/'testing/test_monkeypatch.py',pysrc/'testing/test_mark.py'],env=dict(clean,PYTHONPATH=allpaths))
pytest('upstream-jsonschema',['--pyargs','jsonschema.tests.test_validators','jsonschema.tests.test_types','jsonschema.tests.test_exceptions','jsonschema.tests.test_format'])
cjs=unpack('check-jsonschema-tests')
pytest('upstream-cli',['-o','addopts=',cjs/'tests'],env=dict(clean,PYTHONPATH=allpaths))
# Direct loader observations for the clean installed CLI execution.
run('cli-loader',[cli,'--version'],env={'LD_DEBUG':'libs'})
summary=dict(result='PASS',upstreamAndGCC=summaries,commands=len(records),
    coverage='Local GCC SARIF schemas and real compiler diagnostic fixture; bounded upstream suites, not full GCC conformance')
(evidence/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
(out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')

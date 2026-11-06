"""Installed Tcl/Expect/DejaGNU interfaces and GCC's inherited-descriptor lock.

The sandbox PTY probe is explicit. A host invocation is an independently recorded
nonprivileged control, never a replacement for the raw sandbox upstream runs.
"""
from collections import Counter
import importlib.util
import json
import os
from pathlib import Path
import pty
import re
import shlex
import subprocess
import sys
import time

out, evidence = map(Path, sys.argv[1:3])
out.mkdir(parents=True, exist_ok=True)
evidence.mkdir(parents=True, exist_ok=True)
f = json.loads(os.environ['HARNESS'])
records = []
clean = dict(PATH=':'.join(f[n]+'/bin' for n in ['coreutils', 'sed', 'bash', 'compiler']),
             HOME=str(evidence.resolve()), LOGNAME='builder', TERM='xterm', TZ='UTC',
             TCLLIBPATH=f['expect']+'/lib/expect5.45.4', CHILD_SHELL=f['bash']+'/bin/bash', FLOCK=f['flock']+'/bin/flock')


def run(args, *, data=None, expected=0, env=None, cwd=None):
    p = subprocess.run(list(map(str, args)), input=data, env=clean if env is None else env,
                       text=True, capture_output=True, timeout=60, cwd=cwd)
    record = dict(args=list(map(str, args)), status=p.returncode, stdout=p.stdout, stderr=p.stderr, cwd=str(cwd))
    records.append(record)
    (evidence/'commands.json').write_text(json.dumps(records, indent=2, sort_keys=True)+'\n')
    if expected is not None:
        assert p.returncode == expected, record
    return p


assert run([f['tcl']+'/bin/tclsh'], data='puts [info patchlevel]\n', env={}).stdout.strip() == '8.6.18'
for name, result in [('eval', '42 tvp 3'), ('regexp', 'tvp'), ('zlib', 'tvp preserves what other software is built on')]:
    fixture = json.loads(os.environ['FIXTURES'])[name]
    assert run([f['tcl']+'/bin/tclsh', fixture], env={}).stdout.strip() == result
assert run([f['expect']+'/bin/expect', '-c', 'puts [exp_version]'], env={}).stdout.strip() == '5.45.4'
limitations = run([f['tcl']+'/bin/tclsh'], data='''puts "uid=[exec $env(ID) -u]"
puts "threaded=$tcl_platform(threaded) encoding=[encoding system]"
puts "utc=[clock format 0 -format {%Y-%m-%d %H:%M:%S} -timezone UTC]"
puts "new_york=[clock format 0 -format {%Y-%m-%d %H:%M:%S} -timezone America/New_York]"
foreach address {127.0.0.1 ::1 localhost} {
 set status [catch {socket -server unused -myaddr $address 0} value]
 puts "$address status=$status value=$value"
 if {!$status} {puts [fconfigure $value -sockname]; close $value}
}
puts "Thread package=[catch {package require Thread} value] $value"
''', env=dict(clean, ID=f['coreutils']+'/bin/id'))
assert 'threaded=1' in limitations.stdout and 'utc=1970-01-01 00:00:00' in limitations.stdout
assert 'new_york=1969-12-31 19:00:00' in limitations.stdout
assert '127.0.0.1 status=0' in limitations.stdout
(evidence/'limitations.log').write_text(limitations.stdout)
run([f['localeTools']+'/bin/locale', '-a'], env={})
# Load the installed extension in Tcl, inspect actual native maps after loading.
loaded = run([f['tcl']+'/bin/tclsh'], data='package require Expect\nset f [open /proc/self/maps]; puts [read $f]; close $f\n', env={**clean, 'LD_DEBUG':'libs'})
assert f['expect']+'/lib/expect5.45.4/libexpect5.45.4.so' in loaded.stdout
(evidence/'extension-maps.log').write_text(loaded.stdout)
for path in ['include/tcl.h', 'lib/tclConfig.sh', 'lib/libtclstub8.6.a', 'lib/pkgconfig/tcl.pc', 'lib/tcl8.6/init.tcl']:
    assert (Path(f['tcl'])/path).is_file(), path
assert (Path(f['expect'])/'include/expect.h').is_file()
# A real public header/shared and stub consumer, with environment-discovered flags.
source = out/'embed.c'
source.write_text('''#include <tcl.h>
#include <stdio.h>
static Tcl_ThreadCreateProc worker;
static void worker(ClientData ignored) {Tcl_ExitThread(7);}
int main(int argc,char **argv) { Tcl_FindExecutable(argv[0]); Tcl_Interp *i=Tcl_CreateInterp();
#ifdef USE_TCL_STUBS
if (!Tcl_InitStubs(i,"8.6",0)) return 3;
#endif
if(Tcl_Init(i)!=TCL_OK || Tcl_Eval(i,"expr {6*7}")!=TCL_OK) return 1;
Tcl_ThreadId thread; int status;
if(Tcl_CreateThread(&thread,worker,0,TCL_THREAD_STACK_DEFAULT,TCL_THREAD_JOINABLE)!=TCL_OK) return 4;
if(Tcl_JoinThread(thread,&status)!=TCL_OK || status!=7) return 5;
puts(Tcl_GetStringResult(i)); Tcl_DeleteInterp(i); Tcl_Finalize(); return 0; }
''')
flags = shlex.split(run([os.environ['PKG_CONFIG'], '--cflags', '--libs', 'tcl'], env=dict(os.environ)).stdout)
binary = out/'bin/embed'
binary.parent.mkdir(exist_ok=True)
run([f['compiler']+'/bin/cc', source, '-o', binary, *flags], env=dict(os.environ))
assert run([binary], env={'LD_DEBUG':'libs'}).stdout.strip() == '42'
stub = out/'stub.c'
stub.write_text('''#define USE_TCL_STUBS
#include <tcl.h>
int Tvpstub_Init(Tcl_Interp *i) {
 if (!Tcl_InitStubs(i,"8.6",0)) return TCL_ERROR;
 Tcl_SetVar(i,"stub_answer","42",TCL_GLOBAL_ONLY); return TCL_OK; }
''')
run([f['compiler']+'/bin/cc', '-shared', '-fPIC', '-I'+f['tcl']+'/include', stub,
     f['tcl']+'/lib/libtclstub8.6.a', '-o', out/'stub.so'], env=dict(os.environ))
assert run([f['tcl']+'/bin/tclsh'], data='load {'+str((out/'stub.so').resolve())+'} Tvpstub\nputs $stub_answer\n', env={'LD_DEBUG':'libs'}).stdout.strip() == '42'

assert 'man ' in run([f['dejagnu']+'/bin/dejagnu', 'help', '--DGTest', '-v'], env=clean).stdout

# Genuine libgomp selection and wrapper body, extracted from the pinned source.
gcc = Path(f['gccSource'])
original = (gcc/'libgomp/testsuite/flock').read_bytes()
installed = Path(f['flock']+'/bin/flock').read_bytes()
assert original.split(b'\n',1)[1] == installed.split(b'\n',1)[1]
assert run([f['bash']+'/bin/bash', '-c', 'command -v flock'], env=dict(clean, PATH=f['flock']+'/bin:'+clean['PATH'])).stdout.strip() == f['flock']+'/bin/flock'
assert installed.splitlines()[0] == ('#!'+f['perl']+'/bin/perl').encode()
configure = (gcc/'libgomp/configure.ac').read_text()
assert 'AC_CHECK_PROGS(FLOCK, flock)' in configure and 'AC_CHECK_PROG(FLOCK, perl, $libgomp_abs_srcdir/testsuite/flock)' in configure
libgomp = (gcc/'libgomp/testsuite/lib/libgomp.exp').read_text()
body = libgomp[libgomp.index('if ![info exists ::env(GCC_RUNTEST_PARALLELIZE_DIR)]'):libgomp.index('# Translate offload target')]
lockscript = evidence/'lock.tcl'
lockscript.write_text('''set env(GCC_RUNTEST_PARALLELIZE_DIR) .
set FLOCK $env(FLOCK)
proc verbose {args} {}
proc libgomp_load {program args} {
 set f [open $program a]; puts $f "[pid] enter [clock milliseconds]"; close $f
 after 600
 set f [open $program a]; puts $f "[pid] leave [clock milliseconds]"; close $f
 return completed
}
'''+body+'''
puts [libgomp_load events]
''')
lockdir = evidence/'locking'; (lockdir/'workers').mkdir(parents=True,exist_ok=True)
env = dict(clean, FLOCK=f['flock']+'/bin/flock')
# Both processes run the exact upstream wrapper; helper exit precedes enter.
children = [subprocess.Popen([f['tcl']+'/bin/tclsh', lockscript.resolve()], cwd=lockdir/'workers', env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE) for _ in range(2)]
processes=[]
for child in children:
    stdout, stderr = child.communicate(timeout=15)
    processes.append(dict(pid=child.pid, status=child.returncode, stdout=stdout, stderr=stderr))
    assert child.returncode == 0 and stdout.strip() == 'completed', processes
lines = (lockdir/'workers/events').read_text().splitlines()
assert len(lines) == 4 and [x.split()[1] for x in lines] == ['enter','leave','enter','leave'], lines
assert lines[0].split()[0] == lines[1].split()[0] != lines[2].split()[0] == lines[3].split()[0]
assert int(lines[2].split()[2]) >= int(lines[1].split()[2])
# Invalid protocol must propagate actual failures to Tcl.
for invocation in ['exec $env(FLOCK) --shared 1', 'exec $env(FLOCK) --exclusive 2']:
    result=run([f['tcl']+'/bin/tclsh'], data='if {![catch {'+invocation+'} message options]} {exit 9}\nputs [dict get $options -errorcode]\n')
    assert 'CHILDSTATUS' in result.stdout, result
run([f['tcl']+'/bin/tclsh', lockscript.resolve()], expected=1, cwd=lockdir/'workers', env=dict(clean, FLOCK=f['coreutils']+'/bin/false'))
assert (lockdir/'workers/events').read_text().splitlines() == lines
(evidence/'locking.json').write_text(json.dumps(dict(processes=processes, events=lines, wrapper=body, descriptorRetainedAfterHelperExit=True, selection='PATH flock with upstream Perl fallback also preserved'),indent=2,sort_keys=True)+'\n')

try:
    master, slave = pty.openpty()
except OSError as error:
    pty_scope = dict(supported=False, errno=error.errno, reason=str(error))
else:
    os.close(master); os.close(slave)
    pty_scope = dict(supported=True)
(evidence/'pty.json').write_text(json.dumps(pty_scope,indent=2,sort_keys=True)+'\n')
if pty_scope['supported']:
    assert 'UNBUFFER-PASS' in run([f['expect']+'/bin/unbuffer', f['bash']+'/bin/bash', '-c', 'printf UNBUFFER-PASS'], env={}).stdout
    script = evidence/'pty.exp'
    script.write_text('''set timeout 3
spawn -noecho $env(CHILD_SHELL) --noprofile --norc -c {read -r line; printf "reply:%s\\n" "$line"; exit 7}
send -- "hello\\r"
expect {
 -exact "reply:hello" {}
 timeout {exit 10}
 eof {exit 11}
}
expect eof
set status [wait]
if {[lindex $status 2] != 0 || [lindex $status 3] != 7} {exit 12}
spawn -noecho $env(CHILD_SHELL) --noprofile --norc -c {read -r line}
set timeout 1
expect {
 timeout {}
 eof {exit 13}
}
exec $env(KILL) -TERM [exp_pid]
expect eof
set status [wait]
if {[lindex $status 4] ne "CHILDKILLED" || [lindex $status 5] ne "SIGTERM"} {exit 14}
puts PTY-PASS
''')
    assert 'PTY-PASS' in run([f['expect']+'/bin/expect', script], env=dict(clean, CHILD_SHELL=f['bash']+'/bin/bash', KILL=f['coreutils']+'/bin/kill')).stdout
    spec = importlib.util.spec_from_file_location('harness_results', sys.argv[3])
    parser = importlib.util.module_from_spec(spec); spec.loader.exec_module(parser)
    suites={}
    for mode in ['pass', 'pass-default', 'negative', 'missing-compiler', 'failed-spawn']:
        root = evidence/mode; (root/'testsuite/tvp.all').mkdir(parents=True,exist_ok=True)
        (root/'testsuite/lib').mkdir()
        (root/'testsuite/lib/tvp.exp').write_text('')
        cc = f['compiler']+'/bin/cc' if mode != 'missing-compiler' else '/missing/compiler'
        # target_compile is the installed DejaGNU native unix board interface.
        fixture = '''set timeout 3
foreach {language compiler} [list c $env(CC) c++ $env(CXX)] {
 set src "fixture.[expr {$language eq "c" ? "c" : "cc"}]"
 set f [open $src w]; puts $f {#include <stdio.h>}; puts $f {int main(void) {puts("compiled-42"); return 0;}}; close $f
 set result [target_compile $src program executable [list "compiler=$compiler"]]
 if {$result ne "" || ![file executable program]} {unresolved "compile $language"; continue}
 if {[catch {spawn -noecho ./program} message]} {unresolved "spawn $language"; continue}
 expect {
  -exact "compiled-42" {pass "compiled $language"}
  timeout {fail "compiled $language timeout"}
  eof {fail "compiled $language eof"}
 }
 expect eof; wait
}
'''
        if mode == 'negative':
            fixture += 'fail "controlled failure"\nsetup_xfail *-*-*\nfail "controlled expected failure"\nunresolved "controlled unresolved"\nperror "controlled error"\n'
        if mode == 'failed-spawn':
            fixture += 'if {[catch {spawn /missing/program} msg]} {unresolved "failed spawn"} else {fail "missing program existed"}\n'
        (root/'testsuite/tvp.all/compile.exp').write_text(fixture)
        p=run([f['dejagnu']+'/bin/runtest', '--tool', 'tvp', '--srcdir', 'testsuite', '--host', 'x86_64-unknown-linux-gnu', '--target', 'x86_64-unknown-linux-gnu', *([] if mode == 'pass-default' else ['--target_board=unix'])], data='\n', expected=None, cwd=root, env=dict(clean, CC=cc,CXX=f['compiler']+'/bin/c++', SHELL=f['bash']+'/bin/bash'))
        if mode in ['pass', 'pass-default']:
            suites[mode]=parser.inspect(root,p.returncode)
        else:
            try: parser.inspect(root,p.returncode)
            except (AssertionError,FileNotFoundError) as error:
                assert p.returncode != 0
                observed = Counter(re.findall(r'^(PASS|FAIL|XFAIL|UNRESOLVED|ERROR):', (root/'tvp.sum').read_text(), re.M))
                expected = {'negative': dict(PASS=2, FAIL=1, XFAIL=1, UNRESOLVED=1, ERROR=1),
                            'missing-compiler': dict(PASS=1, UNRESOLVED=1),
                            'failed-spawn': dict(PASS=2, UNRESOLVED=1)}[mode]
                assert dict(observed) == expected, (mode, observed)
                parser.inspect(root, p.returncode, successful=False)
                suites[mode]=dict(rejected=True,status=p.returncode,counts=dict(observed),reason=str(error))
            else: raise AssertionError('negative suite accepted: '+mode)
    (evidence/'dejagnu.json').write_text(json.dumps(suites,indent=2,sort_keys=True)+'\n')
(evidence/'summary.json').write_text(json.dumps(dict(result='PASS',commands=len(records),pty=pty_scope,fullGccSuite=False),indent=2,sort_keys=True)+'\n')

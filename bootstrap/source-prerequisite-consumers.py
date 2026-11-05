"""Real installed native interfaces; every subprocess has retained raw evidence."""
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys


def run(name, args, env=None, expected=0, data=None):
    p = subprocess.run([str(a) for a in args], input=data, env=env,
                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    (evidence / (name + '.log')).write_bytes(p.stdout)
    (evidence / (name + '.status')).write_text(str(p.returncode) + '\n')
    assert p.returncode == expected, (name, p.returncode, p.stdout[-8000:])
    return p.stdout.decode().strip()


if sys.argv[1] == 'installed':
    evidence, out = map(Path, sys.argv[2:4])
    loader, readelf = sys.argv[4:6]
    for program in sorted((out / 'bin').iterdir()):
        run(program.name + '-installed', [program], env={})
        run(program.name + '-loader', [loader, '--list', program], env={})
        run(program.name + '-elf', [readelf, '-h', '-l', '-d', program], env={})
    sys.exit(0)

out, evidence = map(Path, sys.argv[1:3])
spec = json.loads(sys.argv[3])
p = spec['packages']
cc = os.environ['CC']
pkg = os.environ['PKG_CONFIG']
clean_compile = dict(os.environ, NIX_CFLAGS_COMPILE='', NIX_LDFLAGS='')
run('compiler-includes',[cc,'-v','-E','-x','c','-'],data=b'#include <stdio.h>\n#include <stdlib.h>\n')
run('compiler-crt',[cc,'-print-file-name=crt1.o'])
(evidence / 'environment.json').write_text(json.dumps(dict(os.environ), indent=2)+'\n')
for name, macro, pc, lib in [('zlib','ZLIB','zlib','z'), ('bzip2','BZIP2',None,'bz2'),
                              ('xz','XZ','liblzma','lzma'), ('zstd','ZSTD','libzstd','zstd')]:
    root = Path(p[name])
    if pc:
        run(name+'-pc-version', [pkg,'--modversion',pc])
        flags = shlex.split(run(name+'-pc-cflags', [pkg,'--cflags',pc]))
        libs = shlex.split(run(name+'-pc-libs', [pkg,'--libs',pc]))
        assert run(name+'-pc-directory',[pkg,'--variable=pcfiledir',pc]) == str(root/'lib/pkgconfig')
    else:
        flags, libs = ['-I'+str(root/'include')], ['-L'+str(root/'lib'),'-lbz2']
    for mode in ['shared','static']:
        link = libs if mode == 'shared' else [str(root/'lib'/('lib'+lib+'.a')), '-pthread']
        run(name+'-'+mode+'-compile', [cc,'-H','-Wl,-t','-Wl,-Map,'+str(evidence/(name+'-'+mode+'.map')),
            '-D'+macro, spec['codec'],*flags,*link,'-o',out/'bin'/(name+'-'+mode)], env=clean_compile)
# TLS consumer discovers both libraries through the actual owned pkg-config tool.
flags = shlex.split(run('openssl-cflags',[pkg,'--cflags','openssl']))
libs = shlex.split(run('openssl-libs',[pkg,'--libs','openssl']))
run('tls-compile',[cc,'-Wl,-t',spec['tls'],*flags,*libs,'-o',out/'bin/tls'],env=clean_compile)
perl = p['perl']+'/bin/perl'
run('perl-config',[perl,'-V'],env={})
run('perl-native',[perl,'-e',r'''
use strict; use warnings; use utf8; use Cwd; use List::Util qw(sum); use SDBM_File;
use File::Glob qw(bsd_glob); use Fcntl; use Unicode::Normalize;
die unless $^V eq v5.44.0; die unless "é" =~ /\p{Letter}/;
die unless NFC("e\x{301}") eq "é"; die unless sum(1,2,3)==6;
die unless length getcwd(); tie my %h, 'SDBM_File', 'testdb', O_RDWR|O_CREAT, 0600 or die $!;
$h{test}='value'; die unless $h{test} eq 'value'; untie %h;
die unless scalar(bsd_glob('testdb.*'));
open my $maps,'<','/proc/self/maps' or die $!; print while <$maps>;
print "Perl installed XS/Unicode/regex/Cwd PASS\n";
'''],env={'PATH':''})
run('perl-removed-glob',[perl,'-MFile::Glob=glob','-e','1'],env={},expected=255)
# ExtUtils::Embed consumes installed Config, including its real compiler metadata.
opts = shlex.split(run('embed-ccopts',[perl,'-MExtUtils::Embed','-e','ccopts']))
ldopts = shlex.split(run('embed-ldopts',[perl,'-MExtUtils::Embed','-e','ldopts']))
Path('embed.c').write_text('''#include <EXTERN.h>
#include <perl.h>
int main(int argc,char **argv,char **env) {
PERL_SYS_INIT3(&argc,&argv,&env); PerlInterpreter *p=perl_alloc(); perl_construct(p);
char *args[]={"embedded","-e","open my $f, q(<), q(/proc/self/maps) or die $!; print while <$f>; print qq(shared libperl embed PASS\\n)",NULL};
int r=perl_parse(p,NULL,3,args,NULL); if(!r)r=perl_run(p);
perl_destruct(p);perl_free(p);PERL_SYS_TERM();return r;}
''')
run('embed-compile',[cc,'-Wl,-t','embed.c',*opts,*ldopts,'-o',out/'bin/embed'],env=clean_compile)
# A fresh XS extension, built with the installed ExtUtils configuration.
Path('Tiny.pm').write_text("package Tiny;\nuse strict;\nour $VERSION = '0.01';\nrequire XSLoader;\nXSLoader::load('Tiny',$VERSION);\n1;\n")
Path('Tiny.xs').write_text('''#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
MODULE = Tiny PACKAGE = Tiny
int
answer()
  CODE:
    RETVAL = 42;
  OUTPUT:
    RETVAL
''')
Path('Makefile.PL').write_text("use ExtUtils::MakeMaker; WriteMakefile(NAME=>'Tiny',VERSION_FROM=>'Tiny.pm',XS=>{'Tiny.xs'=>'Tiny.c'});\n")
run('xs-configure',[perl,'Makefile.PL'])
run('xs-build',[spec['make'],'SHELL='+spec['shell']])
run('xs-import',[perl,'-Iblib/lib','-Iblib/arch','-MTiny','-e',
    'die unless Tiny::answer()==42; open my $f,"<","/proc/self/maps" or die $!; print while <$f>; print "fresh XS PASS\\n";'],env={})
# Preserve extension and its ELF for independent bounded runtime observation.
import shutil
shutil.copytree('blib',out/'xs')
run('xs-installed-import',[perl,'-I'+str(out/'xs/lib'),'-I'+str(out/'xs/arch'),'-MTiny','-e',
    'die unless Tiny::answer()==42; open my $f,"<","/proc/self/maps" or die $!; print while <$f>; print "installed fresh XS PASS\\n";'],env={})

openssl = p['openssl']+'/bin/openssl'
for flag in ['-a','-d','-m']:
    run('openssl-version'+flag,[openssl,'version',flag],env={})
run('openssl-providers',[openssl,'list','-providers','-provider','default','-provider','legacy'],env={})
run('openssl-modules-override',[openssl,'list','-providers','-provider','legacy'],env={'OPENSSL_MODULES':p['openssl']+'/lib/ossl-modules'})
run('openssl-modules-missing',[openssl,'list','-providers','-provider','legacy'],env={'OPENSSL_MODULES':'/nonexistent'},expected=1)
assert 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad' in run('sha256',[openssl,'dgst','-sha256'],env={},data=b'abc')
assert 'a9993e364706816aba3e25717850c26c9cd0d89d' in run('sha1',[openssl,'dgst','-sha1'],env={},data=b'abc')
Path('message').write_bytes(b'local cryptographic roundtrip\n')
run('aes-encrypt',[openssl,'enc','-aes-256-cbc','-pbkdf2','-pass','pass:fixture','-in','message','-out','encrypted'],env={})
run('aes-decrypt',[openssl,'enc','-d','-aes-256-cbc','-pbkdf2','-pass','pass:fixture','-in','encrypted','-out','decrypted'],env={})
assert Path('message').read_bytes()==Path('decrypted').read_bytes()
assert run('pbkdf2-vector',[openssl,'kdf','-keylen','32','-kdfopt','digest:SHA256','-kdfopt','pass:password','-kdfopt','salt:salt','-kdfopt','iter:1','PBKDF2'],env={}).replace(':','').lower() == '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b'
run('rsa-key',[openssl,'genpkey','-algorithm','RSA','-pkeyopt','rsa_keygen_bits:2048','-out','key'],env={})
run('rsa-public',[openssl,'pkey','-in','key','-pubout','-out','public'],env={})
run('rsa-sign',[openssl,'dgst','-sha256','-sign','key','-out','signature','message'],env={})
run('rsa-verify',[openssl,'dgst','-sha256','-verify','public','-signature','signature','message'],env={})
for mode, decoder in [('gzip',p['zlib']),('xz',p['xz'])]:
    archive='message.'+mode
    run('zstd-'+mode,[p['zstd']+'/bin/zstd','--format='+mode,'-f','message','-o',archive],env={})
    if mode=='gzip':
        assert run('gzip-compatible',[spec['gzip'],'-dc',archive],env={})=='local cryptographic roundtrip'
    if mode=='xz':
        assert run('xz-compatible',[p['xz']+'/bin/xz','-dc',archive],env={})=='local cryptographic roundtrip'
    assert run('zstd-'+mode+'-decode',[p['zstd']+'/bin/zstd','-dc',archive],env={})=='local cryptographic roundtrip'

# Helpers keep an explicit external-utility contract, including source-owned codecs.
helper_env={'PATH':spec['helperPath']}
run('bzip2-compress',[p['bzip2']+'/bin/bzip2','-kf','message'],env={})
run('bzgrep-helper',[p['bzip2']+'/bin/bzgrep','cryptographic','message.bz2'],env=helper_env)
run('bzdiff-helper',[p['bzip2']+'/bin/bzdiff','message.bz2','message.bz2'],env=helper_env)
run('xzgrep-helper',[p['xz']+'/bin/xzgrep','cryptographic','message.xz'],env=helper_env)
run('xzdiff-helper',[p['xz']+'/bin/xzdiff','message.xz','message.xz'],env=helper_env)

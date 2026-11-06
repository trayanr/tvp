"""Installed source-native interfaces and real execution, without an interactive tty."""
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys

out, evidence = map(Path, sys.argv[1:])
packages = json.loads(os.environ['PREREQUISITES'])
fixtures = json.loads(os.environ['FIXTURES'])
records = []


def run(args, *, env=None, expected=0):
    p = subprocess.run(list(map(str, args)), env=env, text=True,
                       stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=180)
    record = dict(args=list(map(str, args)), status=p.returncode, stdout=p.stdout, stderr=p.stderr)
    records.append(record)
    (evidence/'commands.json').write_text(json.dumps(records, indent=2, sort_keys=True)+'\n')
    assert p.returncode == expected, record
    return p.stdout


def build(name, source, flags, *, cxx=False, static=False):
    binary = out/'bin'/name
    run([os.environ['CXX' if cxx else 'CC'], source, '-o', binary, *flags])
    result = run([binary], env={'LD_DEBUG': 'libs', 'TERM':'xterm'})
    if static:
        dynamic = run([os.environ['READELF'], '-d', binary])
        assert 'libisl.so' not in dynamic
    return result


pkg = os.environ['PKG_CONFIG']
flags = lambda name: shlex.split(run([pkg, '--cflags', '--libs', name]))
assert 'PASS' in build('isl-c', fixtures['islC'], ['-DMODERN_API', *flags('isl')])
assert 'PASS' in build('isl-cxx', fixtures['islCxx'], flags('isl'), cxx=True)
static_flags = shlex.split(run([pkg, '--static', '--cflags', '--libs', 'isl']))
static_flags = [str(Path(packages['isl'])/'lib/libisl.a') if x == '-lisl' else x for x in static_flags]
build('isl-archive', fixtures['islC'], ['-DMODERN_API', *static_flags], static=True)
# Public GMP headers must arrive via ISL's declared development dependency.
assert any('gmp-' in x for x in os.environ['NIX_CFLAGS_COMPILE'].split())
Path('api.c').write_text(Path(fixtures['crypt']).read_text())
Path('vectors.h').write_text(Path(fixtures['vectors']).read_text())
crypt = out/'bin/crypt-api'
run([os.environ['CC'], 'api.c', '-fPIE', '-pie', '-o', crypt, *flags('libxcrypt'), '-ldl'])
assert 'PASS bounded API suite' in run([crypt, packages['libxcrypt']+'/lib/libcrypt.so', '4.5.2'], env={'LD_DEBUG':'libs'})
Path('crypt-static.c').write_text('#define _GNU_SOURCE\n#include <crypt.h>\n#include <stdio.h>\nint main(void){struct crypt_data d={0}; char *s=crypt_r("password","$6$salt$",&d); if(!s || *s==42)return 1; puts(s);return 0;}\n')
shared=build('crypt-shared', 'crypt-static.c', flags('libxcrypt'))
crypt_static=[packages['libxcrypt']+'/lib/libcrypt.a' if x=='-lcrypt' else x for x in flags('libxcrypt')]
assert build('crypt-static', 'crypt-static.c', crypt_static)==shared
which = packages['which']+'/bin/which'
assert '2.21' in run([which, '--version'], env={})
assert run([which, 'which'], env={'PATH': packages['which']+'/bin'}).strip() == which
run([which, 'absent-tvp-command'], env={'PATH': packages['which']+'/bin'}, expected=1)
assert run([which, '-a', 'which'], env={'PATH': packages['which']+'/bin:'+packages['which']+'/bin'}).splitlines() == [which, which]
assert Path(packages['which']+'/share/man/man1/which.1.gz').is_file()
assert Path(packages['which']+'/share/info/which.info').is_file()
nc = packages['ncurses']
assert build('terminfo', fixtures['terminfo'], flags('ncursesw')).strip() == '80'
assert build('panel', fixtures['panel'], flags('panelw')+flags('ncursesw')).strip() == 'panel-ok'
Path('wide.c').write_text('''#define _XOPEN_SOURCE_EXTENDED 1
#include <locale.h>
#include <curses.h>
#include <menu.h>
#include <form.h>
#include <stdio.h>
int main(void) {
 if (!setlocale(LC_ALL, "C.UTF-8")) return 1;
 FILE *sink=fopen("/dev/null","w"); SCREEN *s=newterm("xterm",sink,stdin);
 if(!s) return 2;
 cchar_t c; wchar_t w[]=L"\\u03bb"; if(setcchar(&c,w,0,0,0)!=OK) return 3;
 wchar_t got[8]; attr_t a; short pair;
 if(getcchar(&c,got,&a,&pair,0)!=OK || got[0]!=w[0]) return 4;
 ITEM *i=new_item("item","description"); ITEM *items[]={i,0}; MENU *m=new_menu(items);
 FIELD *f=new_field(1,10,0,0,0,0); FIELD *fields[]={f,0}; FORM *form=new_form(fields);
 if(!m || !form) return 5;
 free_menu(m);free_item(i);free_form(form);free_field(f);endwin();delscreen(s);
 puts("wide-menu-form-ok");
}''')
assert build('wide', 'wide.c', flags('menuw')+flags('formw')+flags('ncursesw')).strip() == 'wide-menu-form-ok'
Path('cxx.cc').write_text('''#include <cstdio>
#include <cursesw.h>
int main() { FILE *f=fopen("/dev/null","w"); SCREEN *s=newterm("xterm",f,stdin); if(!s)return 1;
 { NCursesWindow w(2,4,0,0); if(w.height()!=2) return 2; } endwin();delscreen(s);puts("cxx-ok"); }''')
assert build('ncurses-cxx', 'cxx.cc', ['-I'+nc+'/include/ncursesw', '-L'+nc+'/lib', '-lncurses++w', '-lncursesw'], cxx=True).rstrip().endswith('cxx-ok')
symbols=run([os.environ['READELF'], '--wide', '--dyn-syms', nc+'/lib/libncursesw.so'])
assert all(re.search(r'\b'+name+r'(?:@@[^\s]+)?$', symbols, re.M) for name in ['wget_wch','setcchar','tgetent','setupterm'])
run([nc+'/bin/infocmp' , 'xterm'], env={})
run([nc+'/bin/tput', '-T', 'xterm', 'cols'], env={})
run([nc+'/bin/tic', '-V'], env={})
tex = packages['texinfo']
for mode, target in [([], 'manual.info'), (['--html', '--no-split'], 'manual.html'), (['--plaintext'], 'manual.txt')]:
    run([tex+'/bin/makeinfo', *mode, fixtures['manual'], '-o', target], env={'TEXINFO_XS':'required','LD_DEBUG':'libs'})
    assert 'TVP preserves build tools' in Path(target).read_text()
run([tex+'/bin/info', '--file=./manual.info', '--output=read.txt'], env={'LD_DEBUG':'libs'})
assert 'TVP preserves build tools' in Path('read.txt').read_text()
run([tex+'/bin/info', '--version'], env={})
assert Path(tex+'/texmf-dist/tex/texinfo/texinfo.tex').is_file()
modules = list(Path(tex).glob('share/texinfo'))
assert len(modules) == 1
xs = list(Path(tex).rglob('*.so'))
assert xs, 'missing installed parser XS'
# Require the installed parser, and record actual executable mappings in that
# same interpreter after loading XS, rather than infer them from references.
perlcode = 'use Texinfo::ModulePath ("'+str(modules[0])+'", "'+tex+'/lib/texinfo", "'+str(modules[0])+'", installed => 1);' + '''use Texinfo::Parser; my $p=Texinfo::Parser::parser();
my $tree=$p->parse_texi_text("hello\\n"); die unless $tree;
open my $f, '<', '/proc/self/maps' or die $!; print while <$f>;'''
run([os.environ['SOURCE_PERL']+'/bin/perl', '-I'+str(modules[0]), '-e', perlcode], env={'TEXINFO_XS':'required','LD_DEBUG':'libs'})
assert 'UTF-8' in run([os.environ['LOCALE_TOOL'], 'charmap'], env={'LC_ALL':'C.UTF-8'})
translations = (modules[0]/'Texinfo/Translations.pm').read_text()
assert os.environ['LOCALE_TOOL']+' -a' in translations
(evidence/'summary.json').write_text(json.dumps(dict(result='PASS', commands=len(records), parserXS=[str(x) for x in xs]),indent=2,sort_keys=True)+'\n')

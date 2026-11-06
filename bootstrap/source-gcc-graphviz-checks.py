"""Installed, content-sensitive GCC diagram contracts and native public clients."""
import ast
import hashlib
import json
import os
from pathlib import Path
import re
import struct
import subprocess
import sys
import tarfile
import xml.etree.ElementTree as ET
import zlib

out, evidence = map(Path, sys.argv[1:3]); m = json.loads(sys.argv[3])
out.mkdir(); evidence.mkdir(exist_ok=True); work=Path.cwd(); p=m['packages']
env=dict(HOME=str(work/'home'),XDG_CACHE_HOME=str(work/'cache'),
         FONTCONFIG_FILE=m['fonts']+'/etc/fonts/fonts.conf',LC_ALL='C.UTF-8',
         PATH=p['graphviz']+'/bin',TZ='UTC')
Path(env['HOME']).mkdir();Path(env['XDG_CACHE_HOME']).mkdir()
commands=[]
def run(name,args,input=None,expected=0,extra=None):
    e=env | (extra or {})
    r=subprocess.run(list(map(str,args)),input=input,text=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE,env=e)
    commands.append(dict(name=name,args=list(map(str,args)),status=r.returncode,stdout=r.stdout,stderr=r.stderr))
    (evidence/(name+'.stdout')).write_text(r.stdout);(evidence/(name+'.stderr')).write_text(r.stderr)
    (evidence/'commands.json').write_text(json.dumps(commands,indent=2)+'\n')
    assert (r.returncode==expected if expected is not None else r.returncode!=0),(name,r.returncode,r.stderr)
    return r

def png(path):
    data=path.read_bytes();assert data[:8]==b'\x89PNG\r\n\x1a\n';pos=8;compressed=b''
    while pos<len(data):
        size=struct.unpack('>I',data[pos:pos+4])[0];kind=data[pos+4:pos+8];chunk=data[pos+8:pos+8+size]
        assert zlib.crc32(kind+chunk)==struct.unpack('>I',data[pos+8+size:pos+12+size])[0]
        if kind==b'IHDR':w,h,depth,color,_,_,interlace=struct.unpack('>IIBBBBB',chunk)
        if kind==b'PLTE':palette=[chunk[i:i+3] for i in range(0,len(chunk),3)]
        if kind==b'IDAT':compressed+=chunk
        pos+=size+12
    assert (depth==8 and color in (2,6) or color==3 and depth in (1,2,4,8)) and interlace==0,(depth,color,interlace)
    bpp={2:3,3:1,6:4}[color];stride=(w*depth+7)//8 if color==3 else w*bpp;raw=zlib.decompress(compressed);rows=[];previous=bytearray(stride);pos=0
    for _ in range(h):
        filt=raw[pos];pos+=1;row=bytearray(raw[pos:pos+stride]);pos+=stride
        for i in range(stride):
            a=row[i-bpp] if i>=bpp else 0;b=previous[i];c=previous[i-bpp] if i>=bpp else 0
            predictor=a+b-c;dist=(abs(predictor-a),abs(predictor-b),abs(predictor-c));paeth=(a,b,c)[dist.index(min(dist))]
            row[i]=(row[i]+(0,a,b,(a+b)//2,paeth)[filt])%256
        rows.append(bytes(row));previous=row
    assert pos==len(raw)
    pixels=([palette[(row[(i*depth)//8] >> (8-depth-(i*depth)%8)) & ((1<<depth)-1)] for row in rows for i in range(w)]
            if color==3 else [row[i:i+bpp] for row in rows for i in range(0,stride,bpp)])
    assert w>50 and h>30 and len(set(pixels))>1
    return dict(width=w,height=h,colors=len(set(pixels)),decodedSHA256=hashlib.sha256(b''.join(rows)).hexdigest())

def svg(path,labels=()):
    root=ET.fromstring(path.read_bytes());assert root.tag.endswith('svg')
    text=' '.join(root.itertext());assert all(s in text for s in labels),(labels,text)
    ns={'s':'http://www.w3.org/2000/svg'}
    nodes=root.findall('.//s:g[@class="node"]',ns);edges=root.findall('.//s:g[@class="edge"]',ns)
    assert nodes and edges and root.findall('.//s:path',ns) and root.findall('.//s:polygon',ns)
    return dict(nodes=len(nodes),edges=len(edges),texts=[x.text for x in root.findall('.//s:text',ns)])

dot=Path(p['graphviz'])/'bin/dot'
run('version',[dot,'-V'])
match=run('font-match',[Path(p['fontconfig'])/'bin/fc-match','-f','%{file}\n','DejaVu Sans']).stdout.strip()
assert match==m['fonts']+'/share/fonts/truetype/DejaVuSans.ttf'
run('font-scan',[Path(p['fontconfig'])/'bin/fc-scan',match])
config=Path(p['graphviz'])/'lib/graphviz/config6';registry=config.read_bytes();assert b'gd' in registry and b'core' in registry and b'dot_layout' in registry
# Actual compiler-produced flow graph, using the reused checkpoint compiler.
source=work/'flow.c';source.write_text('int choose(int x) { if(x>3) return x*2; return x-1; }\n')
run('compiler-dot',[m['compiler']+'/bin/cc','-O1','-fdump-tree-all-graph','-c',source,'-o',work/'flow.o'])
graphs=sorted(work.glob('flow.c.*.dot'));assert graphs
compiler_graph=graphs[0];assert 'digraph' in compiler_graph.read_text()
# Run the unchanged GCC dg-check-dot body with its actual Expect remote_exec.
gcc=Path(m['gccSource']);body=(gcc/'gcc/testsuite/lib/gcc-defs.exp').read_text();a=body.index('proc dg-check-dot {');b=body.index('\n}\n',a)+3
script=work/'dg.exp';script.write_text('set timeout 60\nproc verbose {args} {}\nproc testname-for-summary {} {return graphviz-owned}\nproc pass {s} {puts "PASS: $s"}\nproc fail {s} {puts "FAIL: $s"; exit 1}\nproc remote_exec {host prog args} {\n set command "$prog [lindex $args 0]"\n set pid [spawn -noecho {*}$command]\n expect eof\n set status [wait]\n return [list [lindex $status 3] $expect_out(buffer)]\n}\n'+body[a:b]+'\ndg-check-dot '+str(compiler_graph)+'\n')
run('gcc-dg-check-dot',[m['expect']+'/bin/expect',script]);generated_png=png(Path(str(compiler_graph)+'.png'))
# Use GCC's own complete expected HTML-table DOT from graphviz.cc selftest.
cc=(gcc/'gcc/graphviz.cc').read_text();start=cc.index('"digraph',cc.index('namespace selftest')) if 'namespace selftest' in cc else -1
# Locate the expected DOT by its struct1 label, then walk back to its digraph literal.
anchor=cc.index('struct1 [label=<<TABLE');start=cc.rfind('"digraph',0,anchor);end=cc.index(';',anchor)
# String literals may contain semicolons; the expected sequence ends at the assertion.
sequence=cc[start:];literals=[]
for item in re.finditer(r'"(?:[^"\\]|\\.)*"',sequence):
    literals.append(ast.literal_eval(item.group()))
    if literals[-1].endswith('}\n'):break
html=''.join(literals);assert 'struct1' in html and '</TABLE>' in html and '->' in html
htmlfile=work/'gcc-html.dot';htmlfile.write_text(html)
r=run('gcc-html-svg',[dot,'-Tsvg'],input=html);htmlsvg=work/'gcc-html.svg';htmlsvg.write_text(r.stdout);svg(htmlsvg)
run('gcc-html-png',[dot,'-O','-Tpng',htmlfile]);htmlpng=png(Path(str(htmlfile)+'.png'))
# Selected font content, multiline labels, non-ASCII, tables, arrows and glyph discrimination.
rich='''digraph gcc { node [fontname="DejaVu Sans"]; a [label="Alpha Ωé\\nsecond line"]; b [shape=plain,label=<<TABLE BORDER="1"><TR><TD>HTML β</TD></TR><TR><TD>value 42</TD></TR></TABLE>>]; a -> b [label="edge",fontname="DejaVu Sans"]; }'''
richfile=work/'rich.dot';richfile.write_text(rich)
r=run('rich-svg',[dot,'-v','-Tsvg'],input=rich);(work/'rich.svg').write_text(r.stdout);richsvg=svg(work/'rich.svg',['Alpha Ωé','second line','HTML β','value 42'])
assert match in r.stderr or 'DejaVuSans' in r.stderr
run('rich-png',[dot,'-v','-O','-Tpng',richfile]);richpng=png(Path(str(richfile)+'.png'))
glyphs=[]
for label in ['IIII','WWWW','Ωβé']:
    f=work/('glyph-'+str(len(glyphs))+'.dot');f.write_text('digraph { a [shape=box,width=2,height=1,fixedsize=true,fontname="DejaVu Sans",label="'+label+'"]; a -> b; }')
    run('glyph-'+str(len(glyphs)),[dot,'-O','-Tpng',f]);glyphs.append(png(Path(str(f)+'.png')))
assert len({g['decodedSHA256'] for g in glyphs})==3
run('bad-dot',[dot,'-Tpng'],input='digraph { a -> }',expected=None)
run('bad-format',[dot,'-Tno_such_format'],input=rich,expected=None)
empty=work/'no-plugins';empty.mkdir()
run('missing-plugins',[dot,'-Tpng'],input=rich,expected=None,extra={'GVBINDIR':str(empty)})
fontless=work/'fontless.conf';fontless.write_text('<fontconfig><dir>'+str(work/'no-fonts')+'</dir></fontconfig>')
run('missing-fonts',[Path(p['fontconfig'])/'bin/fc-match','-f','%{file}'],extra={'FONTCONFIG_FILE':str(fontless)})
assert commands[-1]['stdout']==''
r=run('missing-font-render',[dot,'-Tpng','-o',work/'fontless.png'],input=rich,expected=None,extra={'FONTCONFIG_FILE':str(fontless)})
# Actual loader trace verifies registry-discovered plugins and selected native libs.
run('loader',[dot,'-v','-Tpng','-o',work/'loader.png'],input=rich,extra={'LD_DEBUG':'libs'})
assert config.read_bytes()==registry
assert 'libgvplugin_gd' in commands[-1]['stderr']
run('loader-svg',[dot,'-v','-Tsvg','-o',work/'loader.svg'],input=rich,extra={'LD_DEBUG':'libs'})
assert 'libgvplugin_core' in commands[-1]['stderr']
# Installed C/C++ interfaces, linked only to explicit providers.
client=work/'client.c';client.write_text('''#include <gd.h>
#include <png.h>
#include <expat.h>
#include <ft2build.h>
#include FT_FREETYPE_H
#include <fontconfig/fontconfig.h>
#include <gvc.h>
#include <assert.h>
#include <stdio.h>
int main(void) { FT_Library ft; assert(FT_Init_FreeType(&ft)==0); assert(FcInit());
XML_Parser xp=XML_ParserCreate(0); assert(XML_Parse(xp,"<x/>",4,1)); XML_ParserFree(xp);
assert(png_access_version_number()==10643); assert(gdSupportsFileType("x.png",1));
assert(!gdSupportsFileType("x.jpg",1)); assert(gdSupportsFileType("x.gif",1)); assert(gdFTUseFontConfig(1));
gdImagePtr im=gdImageCreateTrueColor(160,80); gdImageFilledRectangle(im,0,0,159,79,0xffffff);
int box[8]; assert(!gdImageStringFT(im,box,0,"DejaVu Sans",18,0,5,40,"Native Ω"));
FILE *f=fopen("client.png","wb");gdImagePng(im,f);fclose(f);gdImageDestroy(im);
GVC_t *ctx=gvContext();Agraph_t *g=agmemread("digraph {a->b}");assert(gvLayout(ctx,g,"dot")==0);assert(gvRenderFilename(ctx,g,"svg","client.svg")==0);gvFreeLayout(ctx,g);agclose(g);gvFreeContext(ctx);
FT_Done_FreeType(ft); return 0; }''')
libs=['gd','png','expat','freetype','fontconfig','graphviz']
incs=[p[n]+'/include' for n in libs]+[p['freetype']+'/include/freetype2',p['graphviz']+'/include/graphviz']
providers=[p[n]+'/lib' for n in libs]+[p['ltdl']+'/lib',m['zlib']+'/lib',m['bzip2']+'/lib']
flags=['-Wl,-rpath-link,'+x for x in providers]+['-I'+x for x in incs]+['-L'+p[n]+'/lib' for n in libs]+['-Wl,-rpath,'+p[n]+'/lib' for n in libs]+['-lgd','-lpng16','-lexpat','-lfreetype','-lfontconfig','-lgvc','-lcgraph','-lcdt']
for compiler,suffix in [('cc','c'),('c++','cc')]:
    sourcefile=work/('native.'+suffix);sourcefile.write_bytes(client.read_bytes())
    run('compile-'+compiler,[m['compiler']+'/bin/'+compiler,sourcefile,'-o',work/('client-'+compiler),*flags])
    run('client-'+compiler,[work/('client-'+compiler)]);png(work/'client.png');svg(work/'client.svg')
# Explicit public pkg-config path, no setup hooks.
pc=':'.join([p[n]+'/lib/pkgconfig' for n in libs]+[m['zlib']+'/lib/pkgconfig',m['bzip2']+'/lib/pkgconfig'])
run('pkg-config',[m['pkgConfig']+'/bin/pkg-config','--cflags','--libs','gdlib','libpng','expat','freetype2','fontconfig','libgvc'],extra={'PKG_CONFIG_PATH':pc,'PKG_CONFIG_LIBDIR':pc})
# Exercise actual selected generator executables on new inputs.
lex=work/'words.l';lex.write_text('%option noyywrap\n%%\n[a-z]+ { printf("word:%s\\n", yytext); }\n. ;\n%%\nint main(void) { return yylex(); }\n')
run('flex-generate',[p['flex']+'/bin/flex','-o',work/'words.c',lex],extra={'M4':m['m4']+'/bin/m4'})
run('flex-compile',[m['compiler']+'/bin/cc',work/'words.c','-o',work/'words']);assert 'word:hello' in run('flex-run',[work/'words'],input='hello').stdout
hashinput='alpha\nbeta\ngamma\n';r=run('gperf-generate',[p['gperf']+'/bin/gperf','-L','ANSI-C'],input=hashinput);assert 'in_word_set' in r.stdout
hashc=work/'hash.c';hashc.write_text('#include <string.h>\n#include <assert.h>\n'+r.stdout+'\nint main(void) { assert(in_word_set("alpha",5)); assert(!in_word_set("delta",5)); return 0; }\n')
run('gperf-compile',[m['compiler']+'/bin/cc',hashc,'-o',work/'hash'])
run('gperf-run',[work/'hash'])
# Keep upstream outcomes and qualify only the actual supported scope.
upstream={}
for name,root in m['upstream'].items():
    e=Path(root);statuses={x.name:int(x.read_text()) for x in e.glob('*.status')}
    log=(e/(name+'.check.log')).read_text()
    status=statuses[name+'.check.status']
    classification=dict(path=root,statuses=statuses)
    if name in {'flex','png'}:
        counts={k.lower():int(v) for k,v in re.findall(r'^# (TOTAL|PASS|SKIP|XFAIL|FAIL|XPASS|ERROR):\s*(\d+)',log,re.M)}
        assert set(counts)=={'total','pass','skip','xfail','fail','xpass','error'}
        assert counts['total']==sum(counts[k] for k in counts if k!='total') and counts['total']>0
        assert counts['fail']==counts['error']==counts['xpass']==status==0
        classification['cases']=counts
    elif name in {'gd','expat'}:
        records=re.findall(r'\d+/\d+ Test\s+#?\d+:.*?(Passed|Skipped|Failed)',log)
        total=int(re.search(r'(?:tests failed|tests passed) out of (\d+)',log)[1])
        assert len(records)==total>0 and 'Failed' not in records and status==0
        classification['cases']=dict(total=total,passed=records.count('Passed'),skipped=records.count('Skipped'),failed=0)
    elif name=='fontconfig':
        total=int(re.search(r'Ok:\s*(\d+)',log)[1]);assert total==15 and 'Fail:              0' in log and status==0
        classification['cases']=dict(total=total,passed=total,failed=0)
    elif name=='gperf':
        comparisons=len(re.findall(r'^diff ',log,re.M));assert comparisons>0 and status==0
        classification['scope']=dict(expectedOutputComparisons=comparisons,checkTargetStatus=0)
    elif name=='graphviz':
        assert status==8 and 'No tests were found' in log
        classification['scope']='No CTest cases in selected profile; C++ suite needs omitted optional providers. No upstream PASS claim.'
    else:
        assert status==0
        classification['scope']='No upstream cases in this check target; installed native interfaces covered separately.'
    upstream[name]=classification
summary=dict(result='PASS',compilerPNG=generated_png,gccHTMLPNG=htmlpng,richPNG=richpng,richSVG=richsvg,glyphs=glyphs,
             font=match,registry=str(config),registrySHA256=hashlib.sha256(registry).hexdigest(),upstream=upstream,
             contracts=['unchanged GCC dg-check-dot proc / dot -O -Tpng FILE','GCC graphviz.cc expected HTML DOT / dot -Tsvg stdin'],
             commands=len(commands),upstreamConformance=False)
(evidence/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
for file in work.glob('*.png'):(evidence/file.name).write_bytes(file.read_bytes())
for file in work.glob('*.svg'):(evidence/file.name).write_bytes(file.read_bytes())
(out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')

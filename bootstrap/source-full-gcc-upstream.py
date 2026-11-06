"""Reconcile every raw record, completed footer and retained JSON independently."""
import collections
import json
from pathlib import Path
import re
import sys
TAGS='PASS|FAIL|XPASS|XFAIL|UNSUPPORTED|UNRESOLVED|UNTESTED|ERROR|WARNING'
LABELS={'expected passes':'PASS','unexpected failures':'FAIL','unexpected successes':'XPASS',
'expected failures':'XFAIL','unsupported tests':'UNSUPPORTED','unresolved testcases':'UNRESOLVED',
'untested testcases':'UNTESTED','errors':'ERROR','warning messages':'WARNING'}

def inspect(root):
    root=Path(root);raw=json.loads((root/'upstream.json').read_text())['suites']
    assert {str(p.relative_to(root)) for p in root.rglob('*.sum')}==set(raw)
    assert collections.Counter(Path(n).stem for n in raw)==collections.Counter(['gcc','g++','libstdc++','libgomp','libatomic','libitm'])
    totals=collections.Counter();unexpected=[];coverage={}
    for name,suite in raw.items():
        text=(root/name).read_text();tool=Path(name).stem
        headers=list(re.finditer(r'^[ \t]*=== '+re.escape(tool)+r' Summary ===[ \t]*$',text,re.M))
        assert len(headers)==1,(name,'missing/repeated footer')
        records=re.findall(r'^('+TAGS+r'): (.*)$',text,re.M)
        observed=collections.Counter(t for t,_ in records)
        assert observed==suite['counts'] and observed['PASS']>0,(name,'empty or contradictory JSON')
        actual=[t+': '+case for t,case in records if t in {'FAIL','XPASS','UNRESOLVED','ERROR'}]
        assert collections.Counter(actual)==collections.Counter(suite['unexpected'])
        tail=text[headers[0].end():];assert not re.search(r'^('+TAGS+r'): ',tail,re.M)
        footer={}
        for label,n in re.findall(r'^# of (.+?)[ \t]+([0-9]+)[ \t]*$',tail,re.M):
            assert label in LABELS and LABELS[label] not in footer
            footer[LABELS[label]]=int(n)
        assert collections.Counter(footer)==observed,(name,footer,observed)
        assert observed['ERROR']==observed['UNRESOLVED']==0,(name,'requires diagnosis',actual)
        totals.update(observed);unexpected+=actual;coverage[tool]=dict(observed)
    return dict(schema=1,counts=dict(totals),coverage=coverage,unexpected=unexpected,
                completedSummaries=len(raw),strictUpstreamConformance=not unexpected,
                integratedLibraries=['libquadmath','libsanitizer'])

if __name__=='__main__':
    print(json.dumps(inspect(sys.argv[1]),indent=2,sort_keys=True))

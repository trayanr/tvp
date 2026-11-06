"""Validate completed upstream runs; an empty/incomplete/failed run cannot pass."""
from collections import Counter
import json
from pathlib import Path
import re
import sys


def inspect(name, root, compiler=None):
    status=int((root/(name+'.check.status')).read_text())
    log=(root/(name+'.check.log')).read_text()
    records={}
    for path in sorted((root/'raw').rglob('*.trs')):
        results=re.findall(r'^:test-result: (\S+)',path.read_text(),re.M)
        assert results, path
        records[str(path.relative_to(root/'raw'))]=results
    counts=Counter(r for v in records.values() for r in v)
    # Which's upstream check target has no test cases. Installed behavior is
    # checked separately; report that limitation instead of inventing coverage.
    if name!='which':
        assert records and counts['PASS']>0, (name,status,counts)
        assert not (set(counts)-{'PASS','SKIP','XFAIL','FAIL','XPASS','ERROR'}), counts
    assert status==0, (name,status,counts)
    assert not any(counts[k] for k in ['FAIL','ERROR','XPASS']), (name,counts)
    summaries=[dict(zip(['TOTAL','PASS','SKIP','XFAIL','FAIL','XPASS','ERROR'],map(int,m)))
        for m in re.findall(r'# TOTAL:\s+(\d+)\n# PASS:\s+(\d+)\n# SKIP:\s+(\d+)\n# XFAIL:\s+(\d+)\n# FAIL:\s+(\d+)\n# XPASS:\s+(\d+)\n# ERROR:\s+(\d+)',log)]
    if name!='which':
        assert summaries and sum(x['TOTAL'] for x in summaries)==sum(counts.values()), (name,summaries,counts)
    compilers=re.findall(r'libtool: compile:\s+(\S+)', (root/(name+'.build.log')).read_text()) if compiler else []
    if compiler:
        build=(root/(name+'.build.log')).read_text()
        assert compiler in build, (name,'missing native compiler invocation')
        assert all(c==compiler for c in compilers), (name,compilers)
        if name=='texinfo': assert len(compilers)>20, 'missing parser XS compilation'
    return dict(compiler=compiler,libtoolCompilations=len(compilers),status=status,counts=dict(counts),summaries=summaries,records=records,
                scope='upstream make check' if name!='which' else 'empty upstream check target; installed command-selection checks required')


if __name__=='__main__':
    destination=Path(sys.argv[1]); destination.mkdir(parents=True,exist_ok=True)
    result={name:inspect(name,Path(root),sys.argv[3]) for name,root in json.loads(sys.argv[2]).items()}
    (destination/'summary.json').write_text(json.dumps(result,sort_keys=True,indent=2)+'\n')

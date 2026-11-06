"""Qualify retained upstream results against their structured records."""
from collections import Counter
import json
from pathlib import Path
import re


def inspect(name, root):
    e=Path(root);statuses={x.name:int(x.read_text()) for x in e.glob('*.status')}
    log=(e/(name+'.check.log')).read_text()
    status=statuses[name+'.check.status']
    classification=dict(path=root,statuses=statuses)
    if name in {'flex','png'}:
        pairs=re.findall(r'^# (TOTAL|PASS|SKIP|XFAIL|FAIL|XPASS|ERROR):\s*(\d+)\s*$',log,re.M)
        assert len(pairs)==7 and len({key for key,_ in pairs})==7, 'Duplicate/incomplete Automake totals'
        counts={k.lower():int(v) for k,v in pairs}
        outcomes=[]
        for path in e.rglob('*.trs'):
            rows=re.findall(r'^:test-result: (PASS|SKIP|XFAIL|FAIL|XPASS|ERROR)\s*$',path.read_text(),re.M)
            assert len(rows)==1, ('Invalid TRS record',path)
            outcomes+=rows
        actual=Counter(outcomes)
        assert outcomes and len(outcomes)==counts['total']
        assert all(actual[key.upper()]==value for key,value in counts.items() if key!='total'), (counts,actual)
        assert counts['pass']>0
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
        records=[json.loads(line) for line in (e/'meson-logs/testlog.json').read_text().splitlines() if line.strip()]
        assert len(records)==15 and len({row['name'] for row in records})==len(records)
        assert all(row['result']=='OK' and row['returncode']==0 for row in records)
        ok=re.findall(r'^Ok:\s*(\d+)\s*$',log,re.M);failed=re.findall(r'^Fail:\s*(\d+)\s*$',log,re.M)
        assert len(ok)==len(failed)==1 and int(ok[0])==len(records) and int(failed[0])==status==0
        total=len(records)
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
    return classification

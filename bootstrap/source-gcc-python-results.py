"""Require pytest terminal completion, exit status, XML records and footer agreement."""
import re
import xml.etree.ElementTree as ET


def inspect(log, report, status):
    root=ET.parse(report).getroot()
    suites=list(root) if root.tag=='testsuites' else [root]
    counts={k:sum(int(s.attrib[k]) for s in suites) for k in ['tests','failures','errors','skipped']}
    cases=list(root.iter('testcase'))
    assert counts['tests']==len(cases)>0
    for tag,key in [('failure','failures'),('error','errors'),('skipped','skipped')]:
        assert sum(c.find(tag) is not None for c in cases)==counts[key]
    counts['passed']=counts['tests']-sum(counts[k] for k in ['failures','errors','skipped'])
    last_line=log.rstrip().splitlines()[-1] if log.strip() else ''
    terminal=re.fullmatch(r'=+ (.* in .*s) =+',last_line)
    assert terminal, 'Missing terminal pytest completion'
    footer=terminal[1]
    records=[('errors' if label=='error' else label,int(n))
             for n,label in re.findall(r'(\d+) (passed|failed|skipped|errors?|xfailed|xpassed)',footer)]
    assert len(records)==len({label for label,_ in records}), 'Duplicate pytest outcome'
    outcomes=dict(records)
    assert counts['passed']==outcomes.get('passed',0)+outcomes.get('xpassed',0), (counts,footer)
    assert counts['failures']==outcomes.get('failed',0)
    assert counts['errors']==outcomes.get('error',outcomes.get('errors',0))
    assert counts['skipped']==outcomes.get('skipped',0)+outcomes.get('xfailed',0)
    assert (counts['failures']+counts['errors']>0)==(status!=0)
    assert status in (0,1,2)
    return counts

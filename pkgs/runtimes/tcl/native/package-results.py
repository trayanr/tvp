"""Bounded receipts for the full 8.6.18 bundle, including external-client limits."""
import ctypes
import json
from pathlib import Path
import re
import sys


def strings(text, name):
    match = re.search(r'\b' + name + r'\s*(?:\[[^]]*\])+\s*=\s*\{(.*?)\};', text, re.S)
    if not match:
        raise ValueError(f'missing source-owned library-name array: {name}')
    return re.findall(r'"([^"\n]*)"', match[1])


if sys.argv[1] == 'preflight':
    source, output = map(Path, sys.argv[2:])
    result = {}
    for package, stem, prefix in [
        ('tdbcmysql1.1.13', 'mysql', 'lib'),
        ('tdbcpostgres1.1.13', 'pq', 'lib'),
        ('tdbcodbc1.1.13', 'odbc', ''),
    ]:
        text = (source / 'pkgs' / package / 'generic' / f'{stem}StubInit.c').read_text()
        names = strings(text, stem + 'StubLibNames')
        suffixes = [''] if stem == 'odbc' else strings(text, stem + 'Suffixes')
        candidates = [prefix + name + '.so' + suffix for name in names for suffix in suffixes]
        found = []
        for name in candidates:
            try:
                ctypes.CDLL(name)
            except OSError as error:
                # A found but broken library is a failure, not a missing capability.
                if str(error) != f'{name}: cannot open shared object file: No such file or directory':
                    raise
            else:
                found.append(name)
        result[package] = {'status': 0 if found else 77, 'candidates': candidates, 'available': found}
    output.write_text(json.dumps(result, indent=2) + '\n')
else:
    assert sys.argv[1] == 'classify'
    log, preflight, output = map(Path, sys.argv[2:])
    probes = json.loads(preflight.read_text())
    chunks = re.split(r"Testing package '([^']+)'\n", log.read_text())
    sections = dict(zip(chunks[1::2], chunks[2::2]))
    required = {'itcl4.3.7', 'sqlite3.53.0', 'tdbc1.1.13', 'tdbcsqlite3-1.1.13',
                'thread2.8.13', *probes}
    assert set(sections) == required, sorted(set(sections) ^ required)
    receipt = {'schema': 'tvp.tcl-bundled-upstream/v1', 'packages': {}}
    for package, text in sections.items():
        totals = [list(map(int, row)) for row in re.findall(
            r'Total\s+(\d+)\s+Passed\s+(\d+)\s+Skipped\s+(\d+)\s+Failed\s+(\d+)', text)]
        assert totals, (package, 'missing upstream summary')
        assert all(total == passed + skipped + failed and failed == 0
                   for total, passed, skipped, failed in totals), (package, totals)
        assert not re.search(r'\*\*\*.*Error [1-9]|^====.*FAILED', text, re.M), package
        errors = re.findall(r'^Test file error: (.*)$', text, re.M)
        probe = probes.get(package)
        if errors or 'Test files exiting with errors:' in text:
            assert probe and probe['status'] == 77, (package, errors)
            assert errors and all(re.fullmatch(
                r'couldn\'t load file "(lib[^"/]+)": \1: cannot open shared object file: No such file or directory', error)
                for error in errors), (package, errors)
            # The raw upstream fixture errors remain in Nix logs. This is LIMITED,
            # never a passing/empty database integration fixture.
            status = 'unavailable-external-client-library'
        else:
            assert sum(row[0] for row in totals) > 0, (package, 'empty fixture')
            status = 'passed'
        receipt['packages'][package] = {'status': status, 'summaries': totals,
                                       'clientPreflight': probe, 'fixtureErrors': errors}
    output.write_text(json.dumps(receipt, indent=2) + '\n')

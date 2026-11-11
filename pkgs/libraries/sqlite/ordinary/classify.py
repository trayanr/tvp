"""Accept only a complete zero-error SQLite upstream run, never rewrite it."""
from pathlib import Path
from collections import Counter
import json
import os
import re
import subprocess
import sys


SUMMARY = re.compile(r'(?m)^([0-9]+) errors out of ([0-9]+) tests(?: (?:on|in) [^\n]+)?$')
JOB_SUMMARY = re.compile(r'\b([0-9]+) errors out of ([0-9]+) tests(?: on [^\n]+\n)?', re.ASCII)


def job_counts(body):
    """Replay mark_job_as_finished, with complete, unambiguous result evidence.

    Upstream uses the first unanchored summary for every job type (tcl, bld,
    make and fuzz). A job without a summary contributes one case and no errors;
    this permits auxiliary commands without inventing a Tcl-suite result.
    """
    matches = list(JOB_SUMMARY.finditer(body))
    mentions = len(re.findall(r'\berrors out of\b', body, re.ASCII))
    if len(matches) > 1 or mentions != len(matches):
        raise ValueError('duplicate or incomplete runner job summary')
    if not matches:
        return (1, 0)
    hit = matches[0]
    line = body[hit.start():].split('\n', 1)[0]
    if not re.fullmatch(r'[0-9]+ errors out of [0-9]+ tests(?: on [^\n]+)?', line, re.ASCII):
        raise ValueError('incomplete runner job summary line')
    return (int(hit[2]), int(hit[1]))


def raw_text(path):
    if path.is_symlink() or not path.is_file() or path.stat().st_nlink != 1:
        raise ValueError('missing or aliased raw evidence')
    data = path.read_bytes()
    if b'\0' in data:
        raise ValueError('NUL in upstream output')
    return data.decode('utf-8')


def modern_results(root, wrapper, aggregate, inspector):
    """Reconcile the runner's independent log, database and two summaries."""
    log = raw_text(root / 'runner.log')
    path = root / 'runner.db'
    if path.is_symlink() or not path.is_file() or path.stat().st_nlink != 1:
        raise ValueError('missing or aliased runner database')
    if (not isinstance(inspector, str) or not inspector.startswith('/nix/store/')
            or not inspector.endswith('/bin/sqlite3') or not os.access(inspector, os.X_OK)):
        raise ValueError('explicit installed SQLite CLI inspector required')

    def query(sql):
        result = subprocess.run([inspector, '-safe', '-readonly', '-batch', '-json',
                                 '-init', '/dev/null', path.as_uri() + '?mode=ro&immutable=1',
                                 'PRAGMA trusted_schema=OFF; PRAGMA query_only=ON;' + sql],
                                capture_output=True, text=True, check=False)
        if result.returncode or result.stderr:
            raise ValueError('runner database inspection failed')
        try:
            value = json.loads(result.stdout or '[]')
        except ValueError as error:
            raise ValueError('invalid SQLite inspection response') from error
        if not isinstance(value, list) or not all(isinstance(row, dict) for row in value):
            raise ValueError('invalid SQLite inspection rows')
        return value

    if query('PRAGMA quick_check') != [{'quick_check': 'ok'}]:
        raise ValueError('invalid runner database')
    if query("SELECT type FROM sqlite_schema WHERE name='jobs'") != [{'type': 'table'}]:
        raise ValueError('missing runner jobs table')
    keys = ('jobid', 'displayname', 'state', 'ntest', 'nerr', 'output')
    values = query('SELECT jobid, displayname, state, ntest, nerr, output FROM jobs')
    if any(set(row) != set(keys) for row in values):
        raise ValueError('incomplete SQLite inspection row')
    rows = [tuple(row[key] for key in keys) for row in values]
    if not rows or any(type(job) is not int or job < 1 or not isinstance(name, str)
                       or not name or state != 'done' or type(cases) is not int
                       or cases < 0 or type(errors) is not int or errors != 0
                       or not isinstance(body, str) or '\0' in body
                       for job, name, state, cases, errors, body in rows):
        raise ValueError('unfinished or invalid runner job')
    if len({row[0] for row in rows}) != len(rows):
        raise ValueError('duplicate runner job identity')
    jobs, cases, errors, unfinished = map(int, wrapper)
    if (jobs != len(rows) or cases < 1 or cases != sum(row[3] for row in rows)
            or errors != 0 or unfinished != 0 or aggregate != ('0', str(cases))):
        raise ValueError('contradictory runner totals')
    # testrunner.tcl writes one completion header plus trimmed output per job.
    headers = list(re.finditer(r'(?m)^### (.+) [0-9]+ms \(([^()\r\n]+)\)\n', log))
    if not headers or log[:headers[0].start()].strip():
        raise ValueError('missing or unknown runner log records')
    records = Counter((hit[1], hit[2], log[hit.end():headers[i+1].start()
                      if i+1 < len(headers) else len(log)].strip())
                      for i, hit in enumerate(headers))
    expected = Counter((name, state, body.strip()) for _, name, state, _, _, body in rows)
    if records != expected:
        raise ValueError('runner log/database job records disagree')
    for _, _, _, count, errors, body in rows:
        if job_counts(body) != (count, errors):
            raise ValueError('runner job output contradicts database counts')
    return log


def classify(root, inspector=None):
    root = Path(root)
    if root.is_symlink() or not root.is_dir() or not root.is_absolute() or root.resolve(strict=True) != root:
        raise ValueError('not an evidence directory')
    for name in ['exit', 'output']:
        p = root / name
        if p.is_symlink() or not p.is_file() or p.stat().st_nlink != 1:
            raise ValueError('not an independent raw evidence file')
    if (root / 'exit').read_bytes() != b'0\n':
        raise ValueError('upstream nonzero exit: UNWAIVED')
    out = raw_text(root / 'output')
    classic = SUMMARY.findall(out)
    runner = re.findall(r'(?m)^upstream veryquick jobs=([0-9]+) cases=([0-9]+) errors=([0-9]+) unfinished=([0-9]+)$', out)
    if any(int(errors) != 0 for errors, _ in classic):
        raise ValueError('additional nonzero test summary: UNWAIVED')
    modern = bool(runner or (root/'runner.log').exists() or (root/'runner.db').exists()
                  or re.search(r'(?m)^[0-9]+ errors out of [0-9]+ tests in ', out))
    if modern:
        if len(runner) != 1 or len(classic) != 1:
            raise ValueError('incomplete/failed runner summary')
        diagnostics = out + '\n' + modern_results(root, runner[0], classic[0], inspector)
    elif len(classic) != 1 or int(classic[0][0]) != 0 or int(classic[0][1]) < 1:
        raise ValueError('missing/duplicate/failed SQLite test summary')
    else:
        diagnostics = out
    expected_names = {'exit', 'output', 'runner.log', 'runner.db'} if modern else {'exit', 'output'}
    if {path.name for path in root.iterdir()} != expected_names:
        raise ValueError('unexpected raw evidence namespace')
    if re.search(r'(?im)(segmentation fault|core dumped|bus error|^FAIL(?:ED)?\b|^Error:|^.*\.\.\.\s*FAILED\b|^not ok\b|^SQLITE-SKIP:|^.*\.\.\.\s*(?!Ok$)[A-Za-z]+$)', diagnostics):
        raise ValueError('additional failure/unknown skip: UNWAIVED')
    return 'SQLite upstream raw result accepted'


if __name__ == '__main__':
    print(classify(sys.argv[1], sys.argv[2] if len(sys.argv) == 3 else None))

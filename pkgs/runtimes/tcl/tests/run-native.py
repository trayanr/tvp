"""Run unchanged upstream Tcl runners with installed core/package providers.

Keep raw statuses/logs, including tcltest's summary-only failures. The retained
package classifier names unavailable external database clients explicitly.
"""
import json
import os
from pathlib import Path
import re
import subprocess
import sys


def summary(log):
    rows = re.findall(r'Total\s+(\d+)\s+Passed\s+(\d+)\s+Skipped\s+(\d+)\s+Failed\s+(\d+)', log)
    if not rows or not any(int(row[0]) for row in rows):
        raise ValueError('missing nonempty upstream summary')
    if any(int(t) != int(p) + int(s) + int(f) or int(f) for t, p, s, f in rows):
        raise ValueError('upstream test failures')
    if re.search(r'Test file error:|Test files exiting with errors:|^====.*FAILED', log, re.M):
        raise ValueError('upstream fixture error')


def main():
    prefix, shell, timeout, python, classifier, probe = sys.argv[1:]
    prefix = Path(prefix)
    root = Path.cwd().parent
    library = next(p.parent for p in (prefix / 'lib').glob('tcl*/init.tcl'))
    env = os.environ.copy()
    env.update(TCL_LIBRARY=str(library), TCLLIBPATH=str(prefix / 'lib'),
               LD_LIBRARY_PATH=str(prefix / 'lib'), TVP_TEST_SHELL=shell)
    runner = str(Path.cwd() / 'tcltest')
    status = {}

    def run(name, command):
        result = subprocess.run([timeout, '900', *command], env=env,
                                stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT)
        text = result.stdout.decode(errors='replace')
        Path(name + '.log').write_text(text)
        status[name] = result.returncode
        Path('upstream-status.json').write_text(json.dumps(status, indent=2) + '\n')
        print(text, end='', file=sys.stderr)
        if result.returncode:
            raise ValueError(f'{name}: upstream exit {result.returncode}')
        return text

    # The prior core runner read /dev/zero; retain that input, not ambient stdin.
    with open('/dev/zero', 'rb') as zero:
        result = subprocess.run([timeout, '900', runner, str(root / 'tests/all.tcl'),
                                 '-verbose', 'bpse'], env=env, stdin=zero,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    core = result.stdout.decode(errors='replace')
    Path('core-tests.log').write_text(core)
    status['core-tests'] = result.returncode
    Path('upstream-status.json').write_text(json.dumps(status, indent=2) + '\n')
    print(core, end='', file=sys.stderr)
    if result.returncode:
        raise ValueError(f'core upstream exit {result.returncode}')
    summary(core)
    subprocess.run([os.environ['CC'], probe, '-ldl', '-o', 'client-probe'], check=True)
    subprocess.run([python, '-B', classifier, 'preflight', str(root),
                    'client-preflight.json', str(Path.cwd() / 'client-probe')], check=True, env=env)
    logs = []
    for source in sorted((root / 'pkgs').iterdir()):
        if not source.is_dir():
            continue
        all_tcl = source / 'tests/all.tcl'
        if not all_tcl.is_file():
            raise ValueError(f'missing native package runner: {source.name}')
        logs.append(f"Testing package '{source.name}'\n")
        # Native all.tcl / loadTestedCommands selects installed packages through
        # TCLLIBPATH. No package binary from a private build shadows F.
        names = {'itcl': 'Itcl', 'sqlite': 'sqlite3', 'tdbcsqlite3-': 'tdbc::sqlite3',
                 'tdbcmysql': 'tdbc::mysql', 'tdbcpostgres': 'tdbc::postgres',
                 'tdbcodbc': 'tdbc::odbc', 'tdbc': 'tdbc', 'thread': 'Thread'}
        package = next(value for stem, value in names.items() if source.name.startswith(stem))
        logs.append(run(source.name, [runner, str(all_tcl), '-verbose', 'bpse',
                                      '-load', 'package require ' + package]))
    Path('package-tests.log').write_text(''.join(logs))
    subprocess.run([python, '-B', classifier, 'classify', 'package-tests.log',
                    'client-preflight.json', 'package-results.json'], check=True)
    print(Path('package-results.json').read_text(), file=sys.stderr)
    print('upstream-ok')


if __name__ == '__main__':
    main()

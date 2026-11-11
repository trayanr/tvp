"""Exercise CHECKER capture without compiling a package or accepting raw tests."""
import importlib.util
import json
import os
from pathlib import Path
import shlex
import sys
import tempfile


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main(make, ordinary):
    capture = load('capture', ordinary/'capture.py').capture
    classify = load('classify', ordinary/'classify.py').classify
    checker = shlex.join([sys.executable, '-B', str(ordinary/'capture-command.py')])
    python = shlex.quote(sys.executable)
    results = []
    previous = Path.cwd()
    with tempfile.TemporaryDirectory(prefix='xml-capture-') as temporary:
        root = Path(temporary)
        try:
            for name, recipe, outer_exit, exits in [
                ('parallel-identical', f'check: a b\na b:\n\t$(CHECKER) {python} -c \'print("same")\'\n', 0, [0, 0]),
                ('silent', f'check:\n\t$(CHECKER) {python} -c \'pass\'\n', 0, [0]),
                ('failure', f'check:\n\t$(CHECKER) {python} -c \'import sys;print("before failure");sys.exit(7)\'\n', 2, [7]),
                ('ignored-by-make', f'check:\n\t-$(CHECKER) {python} -c \'import sys;sys.exit(7)\'\n', 0, [7]),
            ]:
                work = root/name
                work.mkdir()
                os.chdir(work)
                (work/'Makefile').write_text('.PHONY: check a b\n' + recipe)
                marker = b'W3C raw identity evidence\n'
                (work/'runxmlconf.log').write_bytes(marker)
                raw = work/'raw'
                capture(raw, [str(make), '-j2', 'CHECKER=' + checker, 'check'])
                assert json.loads((raw/'exit.json').read_text())['exit'] == outer_exit, name
                units = list((raw/'commands').iterdir())
                assert sorted(json.loads((p/'exit.json').read_text())['exit'] for p in units) == exits, name
                assert (raw/'runxmlconf.log').read_bytes() == marker
                if name == 'silent':assert (units[0]/'stdout').read_bytes() == b''
                if name == 'parallel-identical':
                    assert len({p.name for p in units}) == 2
                    assert all((p/'stdout').read_bytes() == b'same\n' for p in units)
                # Even when Make ignores a command failure, classification must
                # reject its retained result before considering summary text.
                if name == 'ignored-by-make':
                    (raw/'stdout').write_text('Total 12 tests, no errors\n')
                    try:classify(raw, '2.7.4')
                    except ValueError:pass
                    else:raise AssertionError('ignored command failure was accepted')
                results.append({'case': name, 'outerExit': outer_exit, 'rawCommandExits': exits})
        finally:
            os.chdir(previous)
    return results


if __name__ == '__main__':
    print(json.dumps(main(Path(sys.argv[1]), Path(sys.argv[2]).resolve()), indent=2))

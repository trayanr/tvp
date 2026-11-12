"""Exercise the actual production commands against recursive make dependencies."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


products = [
    'include/production.h',
    'providers/implementations/rands/test_rng.inc',
    'libcrypto.pc',
    'OpenSSLConfigVersion.cmake',
]
fixtures = ['test/provider_internal_test.cnf', 'fuzz/fixture.cnf']
members = products + fixtures

for name, plan in json.loads(Path(sys.argv[1]).read_text()).items():
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        source = root / 'source'
        source.mkdir()
        (root / 'source-date-epoch').write_text('12345\n')
        config = (
            'package configdata; our %unified_info = (depends => {"" => ['
            + ', '.join('q{' + p + '}' for p in members)
            + ']}); 1;\n'
        )
        (source / 'configdata.pm').write_text(config)
        makefile = (
            'GENERATED_MANDATORY=' + ' '.join(members) + '\n'
            '.PHONY: build_sw build_generated install_sw\n'
            'build_sw: build_generated\n'
            'build_generated: $(GENERATED_MANDATORY)\n'
            'install_sw:\n\t@$(MAKE) --no-print-directory build_generated\n'
            + ' '.join(members)
            + ':\n\t@mkdir -p "$(@D)"\n\t@printf generated > "$@"\n'
        )
        (source / 'Makefile').write_text(makefile)
        env = os.environ | {'out': str(root / 'out'), 'TVP_SOURCE_ROOT': str(root)}

        def clear():
            for p in members:
                (source / p).unlink(missing_ok=True)

        for phase in ('build', 'install'):
            clear()
            result = subprocess.run(
                [plan['shell'], '-euc', plan[phase]], cwd=source, env=env,
                text=True, capture_output=True, timeout=30,
            )
            assert result.returncode == 0, (name, phase, result.stdout, result.stderr)
            assert all((source / p).is_file() for p in products), (name, phase)
            assert all(not (source / p).exists() for p in fixtures), (name, phase)
            assert (source / 'configdata.pm').read_text() == config
            assert (source / 'Makefile').read_text() == makefile

        # The unrestricted native target still creates its fixtures. This also
        # reproduces the original production failure when no selector is passed.
        clear()
        result = subprocess.run(
            [plan['make'], '-j1', 'SHELL=' + plan['shell'], 'build_generated'],
            cwd=source, env=env, text=True, capture_output=True, timeout=30,
        )
        assert result.returncode == 0, (name, result.stdout, result.stderr)
        assert all((source / p).is_file() for p in members), name

print('Both production generation selectors and recursive installs passed')

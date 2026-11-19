import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import unittest


SCRIPT = Path(os.environ.get('TVP_PHP_COVERAGE_SCRIPT', Path(__file__).resolve().parents[1] / 'php-coverage.py'))
spec = importlib.util.spec_from_file_location('php_coverage', SCRIPT)
coverage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(coverage)


def row(php, release='1.21.13', state='packaged', reason=None, source=None):
    return {'php': php, 'release': release, 'state': state, 'reason': reason, 'source': source}


class PHPCoverageTests(unittest.TestCase):
    def test_hard_minimum_keeps_source_and_reason(self):
        result = coverage.render({'kind': 'independent', 'rows': [
            row('7.4.33', state='incompatible', reason='Requires PHP 8.1 or newer', source='https://pecl.php.net/get/mongodb-1.21.13.tgz'),
            row('8.2.35'),
        ]})
        self.assertIn('hard limits (1):', result)
        self.assertIn('why: Requires PHP 8.1 or newer', result)
        self.assertIn('source: https://pecl.php.net/get/mongodb-1.21.13.tgz', result)
        self.assertIn('packaging gaps: none', result)

    def test_other_release_support_does_not_hide_gap(self):
        result = coverage.render({'kind': 'independent', 'rows': [
            row('8.2.35', release='6.0.2'),
            row('8.3.36', release='6.0.2', state='gap'),
            row('8.3.36', release='6.3.0'),
        ]})
        older, newer = result.split('    release 6.3.0')
        self.assertIn('packaging gaps (1):\n        8.3.36', older)
        self.assertIn('packaging gaps: none', newer)

    def test_bundled_gap_targets_php_own_release(self):
        result = coverage.render({'kind': 'bundled', 'rows': [
            row('8.2.35', release='8.2.35', state='gap'),
            row('8.5.12', release='8.5.12'),
        ]})
        self.assertIn('bundled releases matching PHP', result)
        self.assertIn('packaged (1): 8.5.12', result)
        self.assertIn('packaging gaps (1):\n        8.2.35', result)

    def test_mixed_source_coverage_uses_its_own_release_groups(self):
        result = coverage.render({'kind': 'mixed', 'rows': [
            dict(row('8.3.35', release='8.3.35'), kind='bundled'),
            dict(row('8.4.27', release='1.0.3'), kind='independent'),
        ]})
        self.assertIn('bundled releases matching PHP\n      packaged (1): 8.3.35', result)
        self.assertIn('release 1.0.3\n      packaged (1): 8.4.27', result)

    def test_built_in_coverage_keeps_its_source_and_is_not_a_gap(self):
        result = coverage.render({'kind': 'bundled', 'rows': [
            row('8.5.12', release='8.5.12', state='builtin',
                reason='PHP always loads OPcache', source='https://www.php.net/opcache.installation'),
        ]})
        self.assertIn('built into PHP (1):\n        8.5.12', result)
        self.assertIn('source: https://www.php.net/opcache.installation', result)
        self.assertIn('packaging gaps: none', result)

    def test_selector_matches_component_boundaries(self):
        data = {'kind': 'independent', 'rows': [row('8.2.35'), row('8.20.0')]}
        self.assertNotIn('8.20.0', coverage.render(data, '8.2'))
        self.assertIn('packaged (1): 8.2.35', coverage.render(data, '8.2.35'))
        self.assertIn('packaged (2):', coverage.render(data, '8'))

    def test_missing_and_invalid_selectors_exit_two(self):
        data = json.dumps({'kind': 'independent', 'rows': [row('8.2.35')]})
        for selector in ('8.3', '8.2.35.1', '--php', ''):
            with self.subTest(selector=selector):
                result = subprocess.run([sys.executable, str(SCRIPT), data, selector], text=True, capture_output=True)
                self.assertEqual(result.returncode, 2)
                self.assertEqual(result.stdout, '')

    def test_sparse_patch_versions_are_counted_without_implied_range(self):
        result = coverage.render({'kind': 'independent', 'rows': [row('8.2.0'), row('8.2.35')]})
        self.assertIn('8.2 (2 versions)', result)
        self.assertNotIn('8.2.0-', result)

    def test_hard_limit_requires_evidence(self):
        with self.assertRaisesRegex(ValueError, 'needs source'):
            coverage.render({'kind': 'independent', 'rows': [row('7.4.33', state='incompatible', reason='Too old')]})

    def test_cli_reads_coverage_from_stdin(self):
        data = json.dumps({'kind': 'independent', 'rows': [row('8.2.35')]})
        result = subprocess.run([sys.executable, str(SCRIPT), '-', '8.2'], input=data, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('packaged (1): 8.2.35', result.stdout)


if __name__ == '__main__':
    unittest.main()

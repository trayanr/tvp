from pathlib import Path
import sys
import tempfile
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from configuration import make_config


class Deployment(unittest.TestCase):
    def settings(self, temporary, enabled):
        secrets = Path(temporary)
        for name in ['worker-password', 'operator-password']:
            (secrets / name).write_text('test-only')
        return {'repository': 'trayanr/tvp', 'controller_revision': 'a' * 40,
                'secrets_directory': str(secrets), 'github_enabled': enabled}

    def test_setup_mode_needs_no_github_token_and_has_no_pollers_or_reporters(self):
        with tempfile.TemporaryDirectory() as temporary:
            config = make_config(self.settings(temporary, False), Path(__file__).resolve().parents[3])
            self.assertEqual(config['change_source'], [])
            self.assertEqual(config['services'], [])
            self.assertEqual(len(config['workers']), 1)
            self.assertIn('127.0.0.1', config['www']['port'])

    def test_enabling_github_requires_a_real_provisioned_credential_file(self):
        with tempfile.TemporaryDirectory() as temporary:
            with self.assertRaises(FileNotFoundError):
                make_config(self.settings(temporary, True), Path(__file__).resolve().parents[3])


if __name__ == '__main__':
    unittest.main()

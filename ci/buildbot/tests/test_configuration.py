from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from configuration import make_config
from buildbot.schedulers.forcesched import ValidationError


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
            step = next(s for s in config['builders'][0].factory.steps
                        if s.kwargs.get('name') == 'full-catalogue')
            self.assertEqual(step.kwargs['sigtermTime'], 30)

    def test_enabling_github_requires_a_real_provisioned_credential_file(self):
        with tempfile.TemporaryDirectory() as temporary:
            with self.assertRaises(FileNotFoundError):
                make_config(self.settings(temporary, True), Path(__file__).resolve().parents[3])

    def test_manual_build_requires_an_exact_commit_in_the_configured_repository(self):
        with tempfile.TemporaryDirectory() as temporary:
            config = make_config(self.settings(temporary, False), Path(__file__).resolve().parents[3])
            scheduler = next(s for s in config['schedulers'] if s.name == 'build-commit')
            fields = {f.name: f for f in scheduler.forcedProperties[0].fields}
            self.assertEqual(fields['repository'].default, 'https://github.com/trayanr/tvp.git')
            self.assertEqual(fields['branch'].default, 'master')
            revision = fields['revision']
            self.assertEqual(revision.getFromKwargs({revision.fullName: ['a' * 40]}), 'a' * 40)
            for value in ['', 'master', 'a' * 7, 'a' * 41]:
                with self.assertRaises(ValidationError):
                    revision.getFromKwargs({revision.fullName: [value]})

    def test_worker_receives_configured_target_independently_of_pr_properties(self):
        with tempfile.TemporaryDirectory() as temporary:
            settings = self.settings(temporary, False)
            settings['branch'] = 'release/next'
            config = make_config(settings, Path(__file__).resolve().parents[3])
            step = next(s for s in config['builders'][0].factory.steps
                        if s.kwargs.get('name') == 'full-catalogue')
            properties = {'revision': 'b' * 40, 'tvp_base': 'c' * 40, 'target_branch': 'untrusted'}
            props = SimpleNamespace(getProperty=lambda key, default=None: properties.get(key, default))
            command = step.kwargs['command'].fn(props)
            self.assertEqual(command[command.index('--target-branch') + 1], 'release/next')


if __name__ == '__main__':
    unittest.main()

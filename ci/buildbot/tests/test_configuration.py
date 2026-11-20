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
                        if s.kwargs.get('name') == 'smoke-catalogue')
            self.assertEqual(step.kwargs['sigtermTime'], 30)
            self.assertEqual(step.kwargs['logfiles'], {
                'graph-diff': 'evidence/graph-diff.log',
                'flake-evaluation': 'evidence/flake-check.log',
                'preparation': 'validation/latest/prepare.log',
                'nix': 'validation/latest/nix.log',
            })

    def test_enabling_github_requires_a_real_provisioned_credential_file(self):
        with tempfile.TemporaryDirectory() as temporary:
            with self.assertRaises(FileNotFoundError):
                make_config(self.settings(temporary, True), Path(__file__).resolve().parents[3])

    def test_catalogue_publication_is_a_required_controller_step_after_upload(self):
        with tempfile.TemporaryDirectory() as temporary:
            settings = self.settings(temporary, False)
            settings['catalogue_publication'] = {
                'script': '/trusted/publish_catalogue.py', 'evidence_root': '/srv/evidence',
                'signing_key': '/private/cache.key', 'cache_uri': 'file:///srv/cache',
                'cache_public_key': 'cache:test',
            }
            config = make_config(settings, Path(__file__).resolve().parents[3])
            steps = config['builders'][0].factory.steps
            self.assertEqual([s.kwargs['name'] for s in steps][-3:],
                             ['validate-catalogue', 'collect-evidence', 'publish-and-verify-nas'])
            properties = {'revision': 'b' * 40, 'buildnumber': 51}
            props = SimpleNamespace(getProperty=lambda key, default=None: properties.get(key, default))
            self.assertIn('--catalogue', steps[-3].kwargs['command'].fn(props))
            self.assertTrue(steps[-1].kwargs['flunkOnFailure'])
            command = steps[-1].kwargs['command'].fn(props)
            self.assertEqual(command[command.index('--base') + 1], 'b' * 40)
            self.assertEqual(command[command.index('--evidence') + 1], '/srv/evidence/51')

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

    def test_master_and_manual_builds_keep_configured_target(self):
        with tempfile.TemporaryDirectory() as temporary:
            settings = self.settings(temporary, False)
            settings['branch'] = 'release/next'
            config = make_config(settings, Path(__file__).resolve().parents[3])
            step = next(s for s in config['builders'][0].factory.steps
                        if s.kwargs.get('name') == 'smoke-catalogue')
            properties = {'revision': 'b' * 40, 'tvp_base': 'c' * 40,
                          'target_branch': 'untrusted', 'tvp_target_branch': 'also-ignored'}
            props = SimpleNamespace(getProperty=lambda key, default=None: properties.get(key, default))
            command = step.kwargs['command'].fn(props)
            self.assertEqual(command[command.index('--target-branch') + 1], 'release/next')

    def test_worker_receives_admitted_pr_target(self):
        with tempfile.TemporaryDirectory() as temporary:
            config = make_config(self.settings(temporary, False), Path(__file__).resolve().parents[3])
            step = next(s for s in config['builders'][0].factory.steps
                        if s.kwargs.get('name') == 'smoke-catalogue')
            properties = {'revision': 'b' * 40, 'tvp_base': 'c' * 40, 'tvp_pr': 192,
                          'tvp_target_branch': 'feature/source-release-discovery',
                          'target_branch': 'untrusted'}
            props = SimpleNamespace(getProperty=lambda key, default=None: properties.get(key, default))
            command = step.kwargs['command'].fn(props)
            self.assertEqual(command[command.index('--target-branch') + 1],
                             'feature/source-release-discovery')

    def test_pr_target_property_is_required(self):
        with tempfile.TemporaryDirectory() as temporary:
            config = make_config(self.settings(temporary, False), Path(__file__).resolve().parents[3])
            step = next(s for s in config['builders'][0].factory.steps
                        if s.kwargs.get('name') == 'smoke-catalogue')
            for target in [None, '', 17]:
                properties = {'revision': 'b' * 40, 'tvp_base': 'c' * 40, 'tvp_pr': 192,
                              'tvp_target_branch': target}
                props = SimpleNamespace(getProperty=lambda key, default=None: properties.get(key, default))
                with self.assertRaisesRegex(ValueError, 'missing its target branch'):
                    step.kwargs['command'].fn(props)


if __name__ == '__main__':
    unittest.main()

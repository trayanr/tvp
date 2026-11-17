import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('android_repository', Path(__file__).parents[1] / 'android-repository.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)


def package(path, revision, channel='channel-0', host='linux'):
    host_tag = '' if host is None else '<host-os>' + host + '</host-os>'
    return ('<remotePackage path="' + path + '"><revision>' + revision + '</revision>'
            '<channelRef ref="' + channel + '"/><archives><archive>' + host_tag
            + '<complete><url>archive.zip</url></complete></archive></archives></remotePackage>')


def document(*packages):
    return '<sdk:sdk-repository xmlns:sdk="urn:fixture">' + ''.join(packages) + '</sdk:sdk-repository>'


class RepositoryTests(unittest.TestCase):
    def test_stable_host_and_explicit_revision_components(self):
        xml = document(
            package('cmdline-tools;23.0', '<major>23</major><minor>0</minor>'),
            package('cmdline-tools;24.0', '<major>24</major><minor>0</minor><preview>1</preview>'),
            package('cmdline-tools;25.0', '<major>25</major><minor>0</minor>', 'channel-1'),
            package('cmdline-tools;22.0', '<major>22</major><minor>0</minor>', host='windows'),
            package('build-tools;37.0.0', '<major>37</major><minor>0</minor><micro>0</micro>'),
        )
        self.assertEqual(adapter.releases(xml, {'packagePrefix': 'cmdline-tools;'}), ['23.0'])
        self.assertEqual(adapter.releases(xml, {'packagePrefix': 'build-tools;'}), ['37.0.0'])

    def test_platform_api_and_revision_with_universal_archives(self):
        xml = document(
            package('platforms;android-36', '<major>2</major>', host=None),
            package('platforms;android-37.2', '<major>3</major>', host=None),
            package('platforms;android-canary', '<major>1</major>', host=None),
        )
        self.assertEqual(adapter.releases(xml, {'packagePrefix': 'platforms;android-', 'versionScheme': 'platform'}), ['36-r2', '37.2-r3'])

    def test_invalid_repositories_and_revisions_reject(self):
        for xml in ('<html/>', '<sdk-repository>', document(package('ndk;30', '<major>unknown</major>'))):
            with self.assertRaises((ValueError, adapter.ET.ParseError)):
                adapter.releases(xml, {'packagePrefix': 'ndk;'})


if __name__ == '__main__':
    unittest.main()

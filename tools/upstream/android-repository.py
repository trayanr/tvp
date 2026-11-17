"""Read stable, host-compatible releases from Android's SDK repository XML."""
import json
import re
import sys
import xml.etree.ElementTree as ET


def local_name(tag):
    return tag.rsplit('}', 1)[-1]


def child(node, name):
    return next((item for item in node if local_name(item.tag) == name), None)


def releases(document, metadata):
    prefix = metadata['packagePrefix']
    scheme = metadata.get('versionScheme', 'revision')
    host = metadata.get('hostOS', 'linux')
    if not isinstance(prefix, str) or not prefix:
        raise ValueError('packagePrefix must be a nonempty string')
    if scheme not in ('revision', 'platform'):
        raise ValueError('unsupported Android version scheme')
    root = ET.fromstring(document)
    if local_name(root.tag) != 'sdk-repository':
        raise ValueError('expected an Android SDK repository')
    result = set()
    for package in root:
        if local_name(package.tag) != 'remotePackage':
            continue
        path = package.get('path', '')
        if not path.startswith(prefix):
            continue
        channel = child(package, 'channelRef')
        if channel is not None and channel.get('ref') != 'channel-0':
            continue
        revision = child(package, 'revision')
        if revision is None:
            raise ValueError('missing revision for ' + path)
        if child(revision, 'preview') is not None:
            continue
        archives = child(package, 'archives')
        if archives is None:
            raise ValueError('missing archives for ' + path)
        compatible = False
        for archive in archives:
            if local_name(archive.tag) != 'archive':
                continue
            archive_host = child(archive, 'host-os')
            if archive_host is None or archive_host.text == host:
                compatible = True
        if not compatible:
            continue
        components = []
        for name in ('major', 'minor', 'micro'):
            value = child(revision, name)
            if value is not None:
                if not re.fullmatch(r'[0-9]+', value.text or ''):
                    raise ValueError('invalid revision for ' + path)
                components.append(value.text)
            elif name == 'major':
                raise ValueError('missing revision major for ' + path)
        if scheme == 'platform':
            match = re.fullmatch(r'platforms;android-([0-9]+(?:\.[0-9]+)*)', path)
            if match is None:
                continue
            version = match[1] + '-r' + components[0]
        else:
            version = '.'.join(components)
        result.add(version)
    return sorted(result)


def main():
    try:
        metadata = json.loads(sys.argv[1])['upstream']
        for version in releases(sys.stdin.buffer.read(), metadata):
            print(version)
    except (KeyError, ValueError, ET.ParseError) as error:
        print('tvp-upstream: invalid Android release index: ' + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())

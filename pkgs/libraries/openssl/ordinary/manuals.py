"""Plan genuine manual restorations from the effective pinned source archive.

No source programs run and no archive paths are extracted. Only checked POD bytes
are sent as data to the selected Perl/Pod::Man helper in an empty scratch directory.
The caller validates the complete resulting namespace and payloads before writes.
"""
from datetime import datetime, timezone
import hashlib
import os
from pathlib import Path
import re
import stat
import subprocess
import tarfile
import tempfile


def regular(path, single_link=True):
    path = Path(path)
    if not path.is_absolute():
        raise ValueError(('absolute manual input required', path))
    for parent in path.parents:
        if not stat.S_ISDIR(parent.lstat().st_mode):
            raise ValueError(('aliased manual input parent', parent))
    st = path.lstat()
    if not stat.S_ISREG(st.st_mode) or (single_link and st.st_nlink != 1):
        raise ValueError(('nonregular/aliased manual input', path))
    return path


def text(data, encoding, name):
    if encoding not in ('latin-1', 'utf-8') or b'\0' in data:
        raise ValueError(('unsafe manual text', name, encoding))
    decoded = data.decode(encoding, errors='strict')
    if str(name).endswith('.pod'):
        declarations = re.findall(r'^=encoding[^\n]*$', decoded, re.M)
        allowed = {'latin-1': {'latin-1', 'iso-8859-1'}, 'utf-8': {'utf-8', 'utf8'}}
        if declarations:
            fields = declarations[0].split()[1:]
            if len(declarations) != 1 or len(fields) != 1 or fields[0].lower() not in allowed[encoding]:
                raise ValueError(('conflicting POD encoding declaration', name, declarations))
    return decoded


def source_pods(config, wanted):
    """Index confined archive names; selected roles and ancestors cannot be links."""
    version = config['version']
    if not re.fullmatch(r'[0-9][A-Za-z0-9.]+', version):
        raise ValueError('invalid manual source version')
    prefix = 'openssl-' + version
    source = regular(config['source'], single_link=False)
    roles, members = {}, {}
    with tarfile.open(source, mode='r:gz') as archive:
        for member in archive:
            name = member.name.rstrip('/') if member.isdir() else member.name
            parts = name.split('/')
            if (parts[0] != prefix or any(p in ('', '.', '..') for p in parts)
                    or any(ord(c) < 32 or ord(c) == 127 for c in name)
                    or name in members or not (member.isfile() or member.isdir() or member.issym())):
                raise ValueError(('unsafe/duplicate source member', name))
            members[name] = member
        def read(name):
            member = members.get(prefix + '/' + name)
            if member is None or not member.isfile():
                raise ValueError(('missing/nonregular source role', name))
            for parent in Path(prefix + '/' + name).parents:
                ancestor = members.get(parent.as_posix())
                if ancestor is not None and not ancestor.isdir():
                    raise ValueError(('aliased source ancestor', name, parent))
            data = archive.extractfile(member).read()
            return text(data, config['encoding'], name)
        # Bind archive layout and the upstream release declaration, not its filename.
        header = read('crypto/opensslv.h')
        versions = re.findall(r'^#\s*define\s+OPENSSL_VERSION_TEXT\s+"OpenSSL ([^ "]+)[^"]*"', header, re.M)
        if versions != [version]:
            raise ValueError(('manual source version mismatch', versions, version))
        for name, member in members.items():
            relative = name[len(prefix)+1:]
            for mapping in config['sections']:
                directory = mapping['directory']
                if not re.fullmatch(r'doc/[a-z]+', directory):
                    raise ValueError('unsafe manual source mapping')
                if Path(relative).parent.as_posix() != directory or not relative.endswith('.pod'):
                    continue
                stem = Path(relative).stem
                section = mapping['exceptions'].get(stem, mapping['section'])
                if not re.fullmatch(r'[1-9]', section):
                    raise ValueError('invalid manual source section')
                role = f'etc/ssl/man/man{section}/{stem}.{section}'
                if role in roles:
                    raise ValueError(('ambiguous source manual role', role))
                # Check all mapped PODs, including aliases/special/bad text, before rendering.
                roles[role] = (relative, read(relative))
        missing = wanted - roles.keys()
        if missing:
            raise ValueError(('missing exact source manual role', sorted(missing)))
    return roles


def plan(root, files, links, config, documentation_role):
    wanted = {name for name, target in links.items()
              if documentation_role(name) == 'documentation' and target == Path(name).name}
    if not wanted:
        return {}, {}
    perl = regular(config['perl'], single_link=False)
    renderer = regular(config['renderHelper'], single_link=False)
    if not str(perl).startswith('/nix/store/') or not os.access(perl, os.X_OK):
        raise ValueError('missing explicit manual Perl provider')
    epoch_name = config['epoch']
    if epoch_name != 'nix-support/source-date-epoch' or epoch_name not in files:
        raise ValueError('missing regular source epoch')
    epoch_text = regular(files[epoch_name]).read_bytes()
    if not re.fullmatch(rb'[0-9]+\n', epoch_text):
        raise ValueError('invalid explicit source epoch')
    epoch = int(epoch_text)
    date = datetime.fromtimestamp(epoch, timezone.utc).strftime('%Y-%m-%d')
    roles = source_pods(config, wanted)
    restorations, evidence = {}, {}
    with tempfile.TemporaryDirectory(prefix='openssl-manual-') as scratch:
        for name in sorted(wanted):
            relative, pod = roles[name]
            stem, section = Path(name).name.rsplit('.', 1)
            if not re.fullmatch(r'[A-Za-z0-9_+-]+', stem):
                raise ValueError(('unsafe manual basename', name))
            if not re.search(r'^=head1 NAME\s*\n', pod, re.M):
                raise ValueError(('missing POD NAME section', relative))
            # Clear PERL5OPT/PERL5LIB and all host date/locale/tool discovery inputs.
            result = subprocess.run([str(perl), str(renderer), section, stem,
                                     config['version'], date],
                                    input=pod.encode('utf-8'), capture_output=True,
                                    cwd=scratch, env={'PATH': '', 'LC_ALL': 'C', 'TZ': 'UTC',
                                                      'SOURCE_DATE_EPOCH': str(epoch)})
            if result.returncode or result.stderr:
                raise ValueError(('manual renderer failure', name, result.returncode, result.stderr))
            rendered = result.stdout
            text(rendered, 'utf-8', name)
            if (not rendered or b'.TH ' not in rendered or not re.search(rb'^\.SH (?:NAME|"NAME")$', rendered, re.M)
                    or b'POD ERRORS' in rendered):
                raise ValueError(('invalid rendered manual', name))
            restorations[name] = rendered
            evidence[name] = {'pod': relative, 'podSHA256': hashlib.sha256(pod.encode(config['encoding'])).hexdigest(),
                              'renderedSHA256': hashlib.sha256(rendered).hexdigest(),
                              'source': config['source'], 'version': config['version'],
                              'encoding': config['encoding'], 'perl': str(perl),
                              'renderHelper': str(renderer), 'epoch': epoch, 'date': date}
    return restorations, evidence

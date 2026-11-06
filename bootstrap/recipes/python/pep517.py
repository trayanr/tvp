"""Small offline PEP 517 invocation and pure wheel layout primitive.

Only wheels just built from the declared source are accepted. No resolver,
network fetch, setup hook or wheel download is involved.
"""
import base64
import csv
import email.parser
import configparser
import hashlib
import importlib
import json
import os
from pathlib import Path
import shlex
import sys
import tomllib
import zipfile

if sys.argv[1] == 'build':
    expected_version = sys.argv[3]
    config = tomllib.loads(Path('pyproject.toml').read_text()).get('build-system', {}) if Path('pyproject.toml').exists() else {}
    backend = sys.argv[2] or config.get('build-backend', 'setuptools.build_meta:__legacy__')
    paths = config.get('backend-path', [])
    for p in paths:
        assert Path(p).resolve().is_relative_to(Path.cwd())
    sys.path[:0] = [str(Path(p).resolve()) for p in paths]
    module, _, attr = backend.partition(':')
    hook = importlib.import_module(module)
    if attr:
        hook = getattr(hook, attr)
    Path('dist').mkdir(exist_ok=True)
    filename = hook.build_wheel(str(Path('dist').resolve()), config_settings={})
    wheel = Path('dist') / filename
    assert wheel.is_file() and filename.endswith('-none-any.whl'), filename
    with zipfile.ZipFile(wheel) as z:
        metadata = email.parser.Parser().parsestr(z.read(next(n for n in z.namelist() if n.endswith('.dist-info/METADATA') and n.count('/') == 1)).decode())
        assert metadata['Version'] == expected_version, (metadata['Name'], metadata['Version'], expected_version)
    Path('build-record.json').write_text(json.dumps(dict(backend=backend, backendPaths=paths,
        declaredBuildRequirements=config.get('requires', ['setuptools', 'wheel']),
        wheel=filename, sha256=hashlib.sha256(wheel.read_bytes()).hexdigest()), indent=2)+'\n')
else:
    out = Path(sys.argv[2]); runtime, python, bash = sys.argv[3:6]
    site = out / 'lib/python3.12/site-packages'; site.mkdir(parents=True)
    wheels = list(Path('dist').glob('*.whl')); assert len(wheels) == 1
    omitted = []
    source_scripts = {}
    with zipfile.ZipFile(wheels[0]) as z:
        for member in z.infolist():
            name = member.filename
            assert not name.startswith('/') and '..' not in Path(name).parts
            # Upstream packaging archives carry Windows binary launchers. Linux
            # entrypoints below use source Python; do not install those payloads.
            if name.endswith(('.exe', '.dll')):
                omitted.append(name); continue
            assert not name.endswith(('.so', '.pyd', '.dylib')), name
            if '.data/' in name:
                _, tail = name.split('.data/', 1)
                kind, name = tail.split('/', 1)
                if kind == 'scripts':
                    body = z.read(member)
                    assert body.startswith(b'#!python'), name
                    source_scripts[name] = body.split(b'\n', 1)[1].decode()
                    continue
                assert kind in ('purelib', 'platlib'), kind
            dest = site / name
            if member.is_dir(): dest.mkdir(parents=True, exist_ok=True)
            else:
                dest.parent.mkdir(parents=True, exist_ok=True); dest.write_bytes(z.read(member))
    paths = str(site) + (':' + runtime if runtime else '')
    scripts = []
    def launcher(name, body):
        dest = out / 'libexec' / (name + '.py'); dest.parent.mkdir(exist_ok=True)
        dest.write_text(body)
        script = out / 'bin' / name; script.parent.mkdir(exist_ok=True)
        script.write_text(f'#!{bash}\nexport PYTHONNOUSERSITE=1\nexport PYTHONPATH={shlex.quote(paths)}${{PYTHONPATH:+:$PYTHONPATH}}\nexec {shlex.quote(python)} -s {shlex.quote(str(dest))} "$@"\n')
        script.chmod(0o755); scripts.append(name)
    for name, body in source_scripts.items():
        launcher(name, body)
    for metadata in site.glob('*.dist-info/entry_points.txt'):
        cp = configparser.ConfigParser(); cp.read(metadata)
        for name, target in cp['console_scripts'].items() if cp.has_section('console_scripts') else []:
            module, attr = target.split(':'); attr = attr.split('[')[0].strip()
            launcher(name, f'import sys\nfrom {module} import {attr} as main\nsys.exit(main())\n')
    for record_path in site.glob('*.dist-info/RECORD'):
        with record_path.open('w') as stream:
            writer = csv.writer(stream)
            for path in sorted(out.rglob('*')):
                if path.is_file() and path != record_path:
                    data = path.read_bytes()
                    digest = base64.urlsafe_b64encode(hashlib.sha256(data).digest()).decode().rstrip('=')
                    writer.writerow([os.path.relpath(path, site), 'sha256='+digest, len(data)])
            writer.writerow([str(record_path.relative_to(site)), '', ''])
    record = json.loads(Path('build-record.json').read_text())
    record.update(omittedWindowsLaunchers=omitted, consoleScripts=scripts)
    (out / 'share/source-python').mkdir(parents=True)
    (out / 'share/source-python/build.json').write_text(json.dumps(record,indent=2)+'\n')

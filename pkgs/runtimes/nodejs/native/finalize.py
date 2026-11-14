"""Relocate installed Node text only; never touch builtin JS/snapshot bytes."""
import importlib.util
import ast
import re
import os
from pathlib import Path
import sys
spec = importlib.util.spec_from_file_location('installed_tree', sys.argv[3])
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
root, files, groups, links = m.tree(Path(sys.argv[1]))
old, new = os.fsencode(sys.argv[2]), os.fsencode(root)
if ('include/node/config.gypi' not in files
        or next(g for g in groups if 'include/node/config.gypi' in g) != ['include/node/config.gypi']):
    raise ValueError('missing/aliased installed Node development configuration')
changes, link_changes = [], []
for name, target in links.items():
    result = os.fsdecode(m.replace_paths(os.fsencode(target), old, new))
    if result != target:
        link_changes.append((root / name, result))
for group in groups:
    p = files[group[0]]
    data = p.read_bytes()
    if group == ['include/node/config.gypi']:
        m.text(data, p)
        config = ast.literal_eval(data.decode())
        if not isinstance(config, dict) or not isinstance(config.get('variables'), dict):
            raise ValueError('invalid installed Node config.gypi')
        if config['variables'].get('node_prefix') != sys.argv[4]:
            raise ValueError('unexpected installed Node configure prefix')
        pattern = rb"(['\"]node_prefix['\"]\s*:\s*)(['\"])([^'\"]*)(['\"])"
        def bind(match):
            if match[2] != match[4] or match[3] != os.fsencode(sys.argv[4]):
                raise ValueError('ambiguous installed Node prefix syntax')
            return match[1] + match[2] + new + match[4]
        result, count = re.subn(pattern, bind, data)
        config['variables']['node_prefix'] = str(root)
        if count != 1 or ast.literal_eval(result.decode()) != config or old in result:
            raise ValueError('Node config changed beyond its installed prefix')
        if result != data:
            changes.append((p, result, p.stat()))
        continue
    if old not in data:
        continue
    if any(Path(n).suffix in {'.json', '.gypi', '.gyp', '.lock', '.sig'} for n in group):
        raise ValueError(('unrecognized structured Node prefix storage', group))
    m.text(data, p)  # Unknown binary storage is an error, including signed archives.
    if not all(n.startswith(('lib/node_modules/', 'include/node/', 'share/')) for n in group):
        raise ValueError(('unknown Node installed metadata owner', group))
    result = m.replace_paths(data, old, new)
    if result != data:
        changes.append((p, result, p.stat()))
for p, result, st in changes:
    p.write_bytes(result)
    os.utime(p, ns=(st.st_atime_ns, st.st_mtime_ns))
for p, target in link_changes:
    p.unlink()
    p.symlink_to(target)

import sys
sys.path.insert(0, sys.argv[4])
"""Render a declared text template in memory; reject incomplete/unknown tokens."""
import re
from pathlib import Path
from shared import invocation, selected

root, config = invocation()
path = config['path']
parent, _, name = path.rpartition('/')
if not parent or not name or name in ('.', '..'):
    raise ValueError('expected relative template file with explicit parent')
directory = selected(root, parent)
target = directory / name
if target.exists() or target.is_symlink():
    raise ValueError(f'template destination already exists: {target}')
text = Path(config['template']).read_text()
values = {key: value.replace('@OUTPUT@', str(root)) for key, value in config['values'].items()}
tokens = set(re.findall(r'@([A-Za-z][A-Za-z0-9]*)@', text))
if tokens != set(values) or any('\0' in v for v in values.values()):
    raise ValueError('template token mismatch or NUL')
text = re.sub(r'@([A-Za-z][A-Za-z0-9]*)@', lambda m: values[m[1]], text)
# Self paths are actual final output paths, never artifact paths.

with target.open('x') as stream:
    stream.write(text)
target.chmod(0o755)

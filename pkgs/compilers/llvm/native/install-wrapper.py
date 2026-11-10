"""Install the native driver using explicit target providers; no PATH discovery."""
import json
import re
from pathlib import Path
import subprocess
import sys

root, template, config = Path(sys.argv[1]), Path(sys.argv[2]), json.loads(sys.argv[3])
# The selected raw GCC supplies its installation layout, not the build compiler.
libgcc = subprocess.check_output([config['gcc'] + '/bin/gcc', '-print-libgcc-file-name'], text=True).strip()
assert libgcc.startswith(config['gcc'] + '/') and Path(libgcc).is_file(), libgcc
config['gccInstallDir'] = str(Path(libgcc).parent)
config['emptyRoot'] = str(root / 'nix-support/empty-sysroot')
config['clang'] = str(root / 'bin/.clang-unwrapped')
(root / 'nix-support/empty-sysroot').mkdir(parents=True, exist_ok=True)
clang = (root / 'bin/clang').resolve(strict=True)
name = clang.name
clang.rename(root / 'bin/.clang-unwrapped')
(root / 'bin/clang').unlink(missing_ok=True)
text = template.read_text()
for key, value in config.items():
    text = text.replace('@' + key + '@', value)
assert not re.search(r'@[A-Za-z][A-Za-z0-9]*@', text)
(root / 'bin/clang').write_text(text)
(root / 'bin/clang').chmod(0o755)
if name != 'clang':
    (root / 'bin' / name).symlink_to('clang')
# Preserve C++ invocation mode even when upstream's alias chain changes.
(root / 'bin/clang++').unlink(missing_ok=True)
(root / 'bin/clang++').symlink_to('clang')
(root / 'nix-support/target-providers.json').write_text(json.dumps(config, indent=2) + '\n')

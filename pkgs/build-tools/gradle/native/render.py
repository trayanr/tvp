"""Render only new, private launcher files beneath the owned output."""
import os
from pathlib import Path
import stat
import sys


def render(out, shell, jdk, core, python, version, template):
    root = Path(out)
    def directory(path):
        info = path.lstat()
        if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid():
            raise ValueError('expected owned directory: ' + str(path))
    if not root.is_absolute() or any(p in ('', '.', '..') for p in str(root).split('/')[1:]):
        raise ValueError('expected canonical absolute output')
    ancestor = Path('/')
    for part in root.parts[1:]:
        ancestor /= part
        if not stat.S_ISDIR(ancestor.lstat().st_mode):
            raise ValueError('non-directory output ancestor')
    directory(root)
    launcher = f'#!{shell}/bin/bash\nexport JAVA_HOME={jdk}\nexport PATH={jdk}/bin:{core}/bin:$PATH\nexec {jdk}/bin/java -classpath "{out}/libexec/gradle/lib/gradle-launcher-{version}.jar" org.gradle.launcher.GradleMain "$@"\n'
    text = Path(template).read_text()
    for name, value in {'python': f'{python}/bin/python3', 'version': version, 'archive': f'{out}/share/gradle/gradle-{version}-all.zip'}.items():
        text = text.replace('@' + name + '@', value)
    files = {'bin/gradle': launcher, 'bin/tvp-gradle-seed-wrapper': text,
             'nix-support/setup-hook': f'export GRADLE_HOME={out}/libexec/gradle\n'}
    # Prevalidate every destination before the first write. O_EXCL also rejects
    # existing symlinks, hardlinks and other inode types without opening them.
    for selector in files:
        path = root
        for part in selector.split('/')[:-1]:
            path /= part
            directory(path)
        if os.path.lexists(root / selector):
            raise ValueError('destination already exists')
    for selector, text in files.items():
        fd = os.open(root / selector, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o644)
        with os.fdopen(fd, 'w') as stream:
            stream.write(text)


if __name__ == '__main__':
    render(*sys.argv[1:])

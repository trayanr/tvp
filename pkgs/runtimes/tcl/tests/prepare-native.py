"""Point the native test-only executable at the installed core and stub archive.

The generated Makefile embeds TCL_BUILD_LIB_SPEC literally. Its two library
prerequisites are replaced by installed files, so make builds only test objects
and dltest fixtures. No production tree is saved or restored.
"""
from pathlib import Path
import re
import sys


if __name__ == '__main__':
    prefix = Path(sys.argv[1])
    config = Path('tclConfig.sh').read_text()
    installed = (prefix / 'lib/tclConfig.sh').read_text()
    old = re.search(r"^TCL_BUILD_LIB_SPEC='([^']+)'$", config, re.M)
    new = re.search(r"^TCL_LIB_SPEC='([^']+)'$", installed, re.M)
    if not old or not new:
        raise ValueError('missing installed Tcl link specification')
    text = Path('Makefile').read_text()
    if old[1] not in text:
        raise ValueError('missing generated Tcl link rule')
    text = text.replace(old[1], new[1])
    libraries = []
    for variable in ('TCL_LIB_FILE', 'TCL_STUB_LIB_FILE'):
        match = re.search(r'^' + variable + r'\s*=\s*(\S+)', text, re.M)
        if not match:
            raise ValueError(f'missing {variable}')
        lib = prefix / 'lib' / match[1]
        if not lib.is_file():
            raise ValueError(f'missing installed prerequisite: {lib}')
        libraries.append(str(lib))
        # Replace both prerequisite and recipe targets with an existing installed
        # file, and mark it old at make invocation to prevent prerequisite rebuild.
        text = re.sub(r'^(' + variable + r'\s*=).*$', lambda m: m[1] + ' ' + str(lib), text, flags=re.M)
    # tcltest must load F, including in sub-interpreters and dltest fixtures.
    text = text.replace('LIB_RUNTIME_DIR="`pwd`"', 'LIB_RUNTIME_DIR="' + str(prefix / 'lib') + '"')
    stub_old = re.search(r"^TCL_BUILD_STUB_LIB_SPEC='([^']+)'$", config, re.M)
    stub_new = re.search(r"^TCL_STUB_LIB_SPEC='([^']+)'$", installed, re.M)
    if not stub_old or not stub_new:
        raise ValueError('missing installed stub link specification')
    text = text.replace(stub_old[1], stub_new[1])
    dltest = Path('dltest/Makefile')
    dltest.write_text(dltest.read_text().replace(stub_old[1], stub_new[1]))
    Path('Makefile').write_text(text)
    Path('fixture-libraries').write_text('\n'.join(libraries) + '\n')

# libxslt features

Libxslt 1.1.8 and later include the libgcrypt-backed EXSLT crypto functions.
The 1.1.8 archive detects the backend automatically. Later archives support
an explicit configure flag. Earlier releases lack the integration.

Python 3 bindings ship from 1.1.35 onward and share the selected libxml2
interpreter and module directory. Bindings in earlier archives that ship
them use the Python 2 module ABI, for which TVP has no source-owned
interpreter. The Python 3 module directory is available as
`package.development.pythonModuleDirectory`. Consumers can set
`withPython = false` or `libgcrypt = null` where these options apply.

# libxml2 features

The default package includes ICU conversion from 2.8.0 and Python 3.11
bindings from 2.9.1. Older archives predate the ICU integration. The
Python bindings in 2.7.4 through 2.9.0 use the Python 2 module ABI, for
which TVP has no source-owned interpreter. The underlying C packages
remain available.

Libxml2 2.15 uses Doxygen to generate the binding descriptions. The Python
module directory is available as `package.development.pythonModuleDirectory`.
Consumers should use the selected `package.specification.bindingPython`
interpreter. The `bindingPython` and `icu` arguments can be set to `null`
when a consumer needs a smaller build.

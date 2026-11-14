The ordinary native build uses the cached full source-GNU driver. Its actual
`-print-file-name` targets resolve both libstdc++ and libgcc_s to the full GCC
output. Those are different from the split runtimes used to construct GCC.
The compiler-runtime test checks both resolved targets and actual loader output.
The independent retained source-owned Patchelf finalizes this executable.

The full upstream suite reports 66 PASS, 4 SKIP and 1 FAIL (71 occurrences,
70 distinct tests). The no-rpath fixture assumes NIX_DONT_SET_RPATH removes all
wrapper paths; the full driver retains its declared runtime paths. The check
requires this exact failure, its actual RPATH, and exactly four upstream skips.
The shared-rpath fixture passes with this driver. No wrapper policy is changed.

The base does not install ldd. The two listing calls in replace-add-needed use
the selected libc loader's --list operation, preserving the fixture's library
extraction, ELF modifications and execution assertions. Test shebangs use the
declared Bash. Fetched archives and the former procedures remain unchanged.

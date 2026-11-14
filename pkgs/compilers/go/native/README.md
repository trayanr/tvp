Only ordinary Go 1.27.3 on x86_64-linux uses this independent native procedure.
`legacy.nix` retains the complete former factory. Earlier release procedures and
the source-built 1.24.13 seed retain their exact construction identities. The
dated 20171003 bootstrap is C source reporting go1.4-bootstrap-20170531.

The owned base supplies runtime.compiler by default. Editing that field selects
a complete owned compiler driver, including its libc, Binutils, C/C++ defaults
and environment contributions. Raw compilers require the owned driver adapter.
Separate libc edits must agree with the driver; the loader belongs to that libc.
Explicit environment CC/CXX overrides remain available and take precedence.
make.bash, cgo, GOROOT_FINAL, share/go and bin aliases remain intact. Build and
focused tests run offline; the installed go.env defaults GOTOOLCHAIN to local
while preserving explicit user overrides. No bootstrap chain is rebuilt.

The effective environment declares sed for make.bash's bootstrap-version query.
Seven installed controls cover the version, selected compiler, offline modules,
compilation, cgo, a standard-library subset and local toolchain selection.
These bounded controls do not establish full all.bash conformance or security
equivalence; hardening qualification remains separate.

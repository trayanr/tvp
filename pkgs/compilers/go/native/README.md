Only ordinary Go 1.27.3 on x86_64-linux uses this independent native procedure.
`legacy.nix` retains the complete former factory. Earlier release procedures and
the source-built 1.24.13 seed retain their exact construction identities. The
dated 20171003 bootstrap is C source reporting go1.4-bootstrap-20170531.

The explicit owned base environment supplies the build and installed default
C/C++ compiler bindings; the selected libc supplies the loader interface.
make.bash, cgo, GOROOT_FINAL, share/go and bin aliases remain intact. Build and
focused tests run offline; the installed go.env defaults GOTOOLCHAIN to local
while preserving explicit user overrides. No bootstrap chain is rebuilt.

The implementation attempt terminated at make.bash's bootstrap-version query:
its required sed provider was missing. The corrected recipe declares retained
sed explicitly in the effective environment. The authorized deterministic-failure
handoff does not retry this build. The corrected recipe and seven regular test
definitions are source-qualified only; installed Go tests, origin/runtime audits
and hardening measurements remain pending a separate bounded follow-up build.
No full all.bash, conformance or security-equivalence claim is made.

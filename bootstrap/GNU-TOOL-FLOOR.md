# Private GNU utility prerequisites

This opt-in wave builds Attr 2.6.0, ACL 2.4.0, Coreutils 9.5, Make 4.4.1,
Findutils 4.11.0 and Diffutils 3.12 with the source-owned GNU GCC 16.2.0
checkpoint. Coreutils 9.5 is the selected catalogue release. No releases,
aliases, default base, compiler generation, libc profile or ordinary functional
test jobs change here.

```
nix-build bootstrap -A gnu-tool-floor
nix-build bootstrap -A gnu-tool-floor-tests
python3 bootstrap/gnu-tool-floor-audit.py
```

Each family has `out` and `evidence` siblings. Evidence retains configure,
config, build, install and raw `make check` logs, exit status and test-suite
logs. The installed contracts run with an empty environment plus an explicit
GNU-only PATH. Their evidence includes exact upstream classification and
independent filesystem preflight results. The strict classifier fails for
unexpected upstream results; raw unsuccessful checks remain unsuccessful.

Construction uses declared source-built musl tools (Make, Coreutils, sed,
grep, awk, diff, find, tar and decompressors) and source-built Python for
preparation/finalization. These are distinct from the GNU runtime profile.
The preparation preserves release timestamps and binds shell shebangs to GNU
Bash. Make directly reuses the catalogue's timestamp-preserving `prepare.py`
with the GNU shell, including its shell-function/default-recipe behavior.
It keeps CXX as `c++` for future caller PATH discovery. This does not provide
a compiler/environment adapter or implement NIX_* flag protocols.

Attr and ACL install static/shared libraries and their commands. ACL uses
Attr's build headers; current libacl does not itself require libattr.
Coreutils enables ACL and GMP, with ELF linkage assertions for cp and factor
and a factor test beyond fixed-width integers. Findutils deliberately installs
find/xargs without the optional locate/updatedb service and its helper payload.
Configure still selects the new GNU sort. Diffutils records GNU Coreutils pr;
installed `diff -l` runs it in the minimal GNU environment. Installed libraries,
commands, scripts and symlinks are checked by the unchanged strict GNU runtime
auditor using an exact additional profile, not a broader global allowlist.

Raw upstream results are bounded by declared prerequisites:

- Attr/ACL cannot run the Perl filesystem harness. Its raw failures/XFAILs are
  retained; they are not filesystem capability allowances or package passes.
- Make returns zero while reporting missing Perl and executing no regression
  suite. The historical catalogue checker requiring one *executed* failure
  cannot classify this different result and is intentionally not invoked.
- Coreutils executes 653 tests: 429 pass, 223 skip, one install-C set-ID
  permission failure. Every fail assignment in that case follows a measured
  permission denial. The installed contracts independently probe set-ID modes.
- Findutils: 2/0, 330/94 and 25/4 pass/skip across its three summaries, no
  failures. Diffutils: 27/6 and 263/81, no failures. Missing locale, Perl,
  privileged, optional harness and expensive-test coverage remains in raw logs.

Installed Attr/ACL consumers always check linkage and in-memory behavior;
filesystem round-trips run only after independent kernel/libc preflight.
The validation sandbox rejects user xattrs and named ACLs with EOPNOTSUPP. Separate
nonprivileged host-filesystem observer coverage can run the same GNU binaries
and GNU-only command environment; it is explicitly distinct from sandbox
coverage. No host commands enter the source builds.

This remains a utility prerequisite profile. It makes no complete-base,
compiler discovery, full upstream conformance, locale/gconv, privileged/NFS,
reproducibility or compiler-generation comparison claim. The reduced libc
profile and libc APIs that invoke `/bin/sh` remain later work. Make's libc
fallback PATH when PATH is absent remains `/bin:/usr/bin`; callers needing
external recipe commands must declare their GNU PATH. ABI wrapper guards are
convenience checks, not sandboxing. The compiler/environment adapter, deliberate
libc generation, and remaining unpack/finalization helper selection are separate
prerequisites. Parent review, publication, exact CI and master reconciliation
remain required.

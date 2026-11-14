# Tcl family

All82 supported registered releases use an inline recipe/release table and the
implicit owned family constructor, effective base tools and shared installed suite.
Historical source hashes, fallback URLs, patch reasons and Tcl9 degraded status
are preserved. Tcl9's script image remains disabled; its zipfs command remains
available. No external database client library is substituted or newly promised.

Four independent complete procedures preserve the actual existing profiles:
`build-8.0.2.nix` (8.0–8.5, no zlib/packages); `build-8.6.0.nix` (early8.6 and9.0
bundled packages); `build-8.6.18.nix` (current Tcl8 ABI/private headers/full bundle);
and `build-9.1.0.nix` (Tcl9 stub ABI/Thread3/explicit ZIP image limit).
Narrow dialect/unwinder/version/ZIP choices are grouped literal options; the
old dialect is a stable builder default. Helpers remain at their existing paths.

The zlib dependency is an ordinary TVP package choice. libgcc retains exactly
the standalone raw full-GCC output selected by the existing full-tier driver,
through its `compiler.tvp.deps.compiler` metadata. This is a construction/runtime
role, not a public-GCC dependency. Root must verify its evaluated identity.

Every procedure installs before its equal-width artifact/final split. Prefix,
shell, loader, RPATH, archive/header metadata and safety repairs remain in F.
Tcl9's shipped HTTP cancellation repair stays in F; its offline HTTP/home-shell
fixture patch remains test-only. Installed API/assertion bodies and whole-test
guards are shared, with real version-specific ABI/package contracts retained.

Native U still configures a private source tree, builds tcltest/dltest fixtures
against installed F core/stub libraries, and runs unchanged core/package runners.
It does not restore A from a checkpoint. Test-source/patch/shell/Python/preparation/
runner/expectation edits remain independent of A/F. Historical profiles gain no
new upstream gate. Existing raw failures/skips and external-client limits remain.

Construction callers explicitly use `retained-construction.nix`, byte-identical
old procedures under `retained/`, original8/9 release tables and original tests.
The bootstrap-owned Tcl provider remains untouched. Old source-stage context is
`retained/README.md`; it is historical evidence, not current qualification.

Standard tools are customized through the effective base or selected steps. A
compiler Binutils edit is a production change. The final-only inspector contract
therefore edits explicit suffix steps after the split; test-inspector binding
controls use the selected base. Runtime shell/library edits retain their own role.

This candidate has source/syntax/hash checks only. Producer equality, compilation
and runtime behavior remain unmeasured; all prior failures and gates are unwaived.

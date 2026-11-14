# Ruby and Bundler source migration

The public x86_64 Linux catalogue uses complete version-start procedures here.
The retained procedures, release tables, hashes, patches, dependency API lines and
status declarations are unchanged. `../retained-public.nix` is the accepted public
Ruby selector, retained verbatim so Bundler's construction recipe can keep its
previous Ruby tools rather than following the migrated public aliases. Other
platforms retain their existing route.

Construction boundaries are 2.0 (external Fiddle), 2.2 (vendored Fiddle), 2.6
(MJIT command flags), 2.7.4 (implicit CFLAGS initialization), 3.1 (GDBM removal),
3.2 (external Psych/Fiddle and Rust YJIT), 3.3 (Readline removal), and 4.0
(ZJIT and bundled Fiddle). The latest native 3.4.10/4.0.6 procedures keep their
explicit current tool assignments and native test suites. No versioned procedure
imports another. Dependency choices remain in the accepted definitions; this
migration does not migrate LibYAML or upgrade historical OpenSSL/Rust providers.

Each procedure installs before `steps.split`. Ruby uses the existing equal-width
artifact name and reviewed `perl/ordinary/elf-finalize.py` mechanics unchanged:
installed text and links, validated readonly ELF strings and exclusive dynamic
RPATHs are relocated with preserved widths and hardlinks. This is a deliberate
reuse of mechanical output repair, not a new generic relocation protocol. The Ruby-only `finalize.py` adapter preserves
historical `lib/libruby-static.a`: it validates native non-LTO members and rewrites
only equal-width readonly path strings before invoking that reviewed procedure.
Archive symbol indices are regenerated with the selected GNU ar; unknown sections
or member formats fail closed. Unsupported
compiled locations fail closed. Stripping precedes relocation in the suffix so discarded debug macros cannot
masquerade as runtime path strings. Library provider selection, interpreter
repair, manual compression and final checks follow relocation. Bundler installs
its exact source gem before the split and writes pinned-version wrappers using
the effective runtime Ruby afterward. Runtime edits therefore preserve A.

The shared historical suites and fixtures now accept an owned test context while
keeping legacy callers' test builders. Feature guards remain whole-test guards.
The current native suites are retained. The new installed shared embedding control
uses the independent consumer compiler. Upstream `bootstraptest/runner.rb` runs
against the final Ruby in a separate registered `upstream-basic` test, using its
matching source; no build tree, test-only dependency or result classifier feeds
A/F. Disabling that test changes the test set, never production identities.

`tests/family-source.nix` evaluates every public family release and variant and
checks split/output/edit/test-factory contracts. Source evaluation and tiny split
fixtures are not compilation or runtime qualification. All migrated releases
remain uncompiled and unqualified; a later shared latest-only qualification must
check relocation, installed runners, shared embedding, extension/header/RbConfig
consumers, RubyGems, native launchers and Bundler offline operation. Existing
historical, upstream, hardening, runtime, default and full-validation holds remain.

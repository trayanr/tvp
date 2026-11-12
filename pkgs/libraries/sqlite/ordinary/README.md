# Ordinary SQLite upstream isolation (source implementation)

Scope: all 268 supported ordinary releases, 3.0.0–3.53.3. The independent
native 3.53.4 procedure and retained construction definitions/tables are unchanged
and UNAUDITED for upstream isolation. This is source inspection plus tiny fixture
validation. No new canonical A/F/T/R/U has been runtime qualified. Existing six
representative proofs certify their old identities only; keep their roots.

Both version-start procedures remain complete: unpack, production prepare and
patches, configure, make all, install, checkpoint, one split, copy, drop checkpoint,
normal installed-output repair/audits. Tcl generators/installed bindings, readline,
production compatibility flags and real engine fixes remain production inputs.
Signed48 serialization and unsigned INT64_MIN magnitude repairs stay before build.
The callback fix named async-dlsym changes only src/test_async.c and moves to T.
Test adapter/init/corruption/recovery/portability patches preserve their original
release boundaries, source preconditions and effective order (inherited async
adapter, runtime test adapters, then portability patches). Production definition
patches remain before runtime engine patches.

The required owned test factory is reattached by the existing native recipe
adapter after override/edit. Its existing mkTest supports specification edits;
validation metadata uses `.edit`, never a result-record wrapper. No test factory
API or comparison runner changed. Internal T/R have validation roles, are genuine
owned derivations, and are not canonical packages or fake named passing tests.

* A: production installed products and `nix-support/upstream-build-tree/{tree.tar,layout.json}`.
* F: copy A, remove the entire sidecar, then normal relocation, stripping, RPATH,
  development metadata and path checks. Existing artifact-reference exclusions apply.
* T: privately restore A, apply checked effective `testPatches`, prepare private
  metadata and make testfixture with effective test flags/providers. Checkpoint
  the private fixture tree. 3.0.0 intentionally compiles a private SQLITE_TEST
  pragma/pager engine; there is no claim of zero fixture-engine compilation.
* R: privately restore T, repeat the required old libtool relink environment,
  execute quick.test or modern --jobs 8 veryquick with timeout 900. Capture native
  status/output and available runner.log/runner.db. Missing modern evidence stays
  missing so U rejects it; successful capture does not imply acceptance.
* U: registered `tests.upstream`, owned mkTest, unchanged strict classifier over R.
  Modern U explicitly names F/bin/sqlite3 to reconcile the independent database,
  log, job counters and summaries. Historical U does not consume F.
* Existing installed consumers use F. U and installed tests gate normal batches.

Effective test-only fields: testZlib, testPatches (reasoned file records),
testCompileFlags, testFixtureRelinks, testPrepareScript, testRestoreScript, captureScript,
classifyScript, runnerScript, upstreamExpected. `tvp.testDeps` exposes those
relationships. Neither A nor F consumes them. Tcl's zlib is a real production
search provider too; the policy records that shared provider explicitly and uses
both differential identities and actual contexts rather than banning its path.
Source, base/compiler, production patches/options, prepareScript, stateScript and
stateManifest remain real production inputs. No separate testSource is needed:
the prepared production source is inherited from A. Replacing the whole source
archive invalidates production, even if its human diff concerns tests.

## Retained state

`retained-state.json` is a conservative per-protocol allowlist grounded in the
cached pinned 3.0.0 and 3.48.0 Makefile.in/main.mk. It retains upstream source roots,
configured/generated Makefiles/headers/amalgamation/parser/generator tools, object,
archive, dependency, libtool and Tcl metadata, `.libs`, `.deps` and `tsrc`. It does
not copy a repository/workspace or installed output directory. Build-tree CLI and
library products may be required by upstream fixture targets; they are build
state, distinct from copying the installed tree again. Temporary DBs, raw logs,
test executables (in A), history and unrelated roots are excluded. T additionally
retains its fixture. Exact minimum members, reuse and archive/copy cost are later
pilot measurements; this allowlist is intentionally conservative.

The checkpoint is after install (which can relink libraries), before split, and
before any test patch. The layout records the canonical source path, original
configured prefix, exact members, protocol and source-date epoch. Tar preserves
modes, mtimes and internal relative links. Validation refuses special files,
external/hard links, unsafe members and extraction through symlinks. Restores are
writable independent copies, never links into store outputs. Sandboxed absolute
layout is reused if available; otherwise only identified generated Makefile,
config.status/libtool/auto.def/Tcl/.la/.lai/.lo/dependency metadata and the old
libtool shell fixture launcher (never the modern ELF fixture) is rebased privately.
The configured production prefix is preserved; neither installed production nor
its prefix is redirected to test evidence. Restore/rebase code is a separate effective test input, so restore-only edits
preserve production. No configure or make all is dispatched by the snapshot helper. Historical test preparation invokes saved config.status
substitutions only if Makefile.in changed. Unknown modern Makefile.in changes fail
closed until an explicit private substitution protocol exists; current modern
test patches do not change it. Existing source mtime ordering is retained.

The evaluated policy separately reports isolation debt and artifact/final debt;
UNAUDITED is not a pass. Scoped admission checks inspected rows and exposes strict
admission separately, leaving debt/holds visible without adding a permanently
failing global check. It validates fresh producers and complete selected outputs,
active command accounting/roles, Nix dependency contexts (including child scripts),
required registration and test-field differentials. Tiny controls exercise
invalidation, forged identities, reverse inputs, misplaced tests, strict debt,
safe retained-state copies and actual failed U/batch with valid A/F. Existing named
output leak controls and audits/split-baseline.json are preserved. Evaluated
metadata cannot prove arbitrary shell behavior; independent source review and the
later authorized 3.0.0/3.48.0 pilots remain required.

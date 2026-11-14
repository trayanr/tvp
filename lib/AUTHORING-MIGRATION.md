# Rolling out the MPFR package model

The accepted package model is documented in [NATIVE-RECIPES.md](NATIVE-RECIPES.md).
MPFR implements it. The next work is to simplify construction-base composition,
then convert complete package families while preserving their actual procedures
and earlier construction inputs.

[MIGRATION-DECISIONS.md](MIGRATION-DECISIONS.md) records scope exceptions and design
questions found during implementation. Keep them explicit for later review instead
of adding a package-specific workaround or silently broadening this rollout.

## Migration execution policy

On 2026-11-14 the owner approved suspending the required `tvp/full` merge check
until this migration is complete. Other branch protections stay unchanged. Keep
CI execution and NAS/cache synchronization off; use scoped Tower-local validation
and cached outputs, with no synthetic passing CI status. Merging the baseline or
later cleanup does not waive qualification limits, hardening holds or historical
failures.

When the owner declares completion, restore strict `tvp/full` protection and
explicitly re-enable CI and NAS operations. The [CI migration workflow](../ci/README.md#temporary-migration-workflow)
records the exception and restoration policy; the normal CI workflow remains
documented for use afterward.

## What is already done

- The owned constructor, artifact/final split, generic helpers and shared test
  factory exist.
- `mkFamily` supplies implicit ordinary context, source/test wiring and stage-local
  `.instantiate { version; base; deps; opts; }`.
- Base tiers expose `seed`, `target`, `native`, `full` and retained input adapters.
  Ordinary standard-tool choices live in one explicit record.
- MPFR has one readable family index and two independent era builders. Base,
  dependency, specification, step and runtime edits remain available.

These are separate measures of progress. Split compliance describes evaluated
production plans. Adoption of the MPFR authoring model describes how families and
their construction callers are written. Runtime qualification describes executed
tests of particular outputs. None implies the other two.

A static source inventory at commit `6d626ef6f31975d0f4a0558f4a861877cfb112cd`
found 110 family entrypoints: 46 libraries, 38 build tools, 13 runtimes, seven SDKs,
five compilers and one data family. Only MPFR used `mkFamily`; the other 109 still
used earlier wiring. This count inspects tracked files matching
`pkgs/<category>/<family>/default.nix`; it is not an evaluation or build result.
The current `status --migration` report measures split coverage, not completion of
this authoring cleanup.

From the implementation checkout:

```sh
nix run .#status -- --migration
```

## 1. Finish production/test separation beneath the full base

The retained full-GCC boundary is implemented and locally qualified with its
recorded native and historical limits.
[`bootstrap/source-full-gcc.nix`](../bootstrap/source-full-gcc.nix) now imports
production prerequisites directly and instantiates the same complete
[GCC16 procedure](../pkgs/compilers/gcc/native/build-16.2.0.nix) used publicly.
The duplicate retained compiler procedure has been removed. Production uses raw
construction Python; the validation profile and upstream harness belong to the
independent test factory. Existing harness exports stay lazy for caller compatibility.

Bootstrap comparison remains a production requirement. The artifact retains its
production provenance and configured-tree checkpoint; finalization repairs the
installed output. Upstream execution/acceptance is attached through the existing
test factory and remains a normal validation gate. The driver consumes artifact
provenance at build time, without making it part of its intended runtime interface.
See the [construction reference](../bootstrap/source-full-gcc.md) for boundaries
and historical measurement limits.

Done when a test-tool, test-reader or acceptance-policy edit leaves the compiler's
artifact/final identities unchanged, and failed upstream acceptance leaves those
production outputs usable. Changing this graph can require a deliberate compiler
rebuild; later test-only corrections must reuse it.
Changing the underlying full compiler can also change full-base and downstream
identities. Earlier native/seed provider identities must remain unchanged. The open
audit, provider-role and checkpoint decisions are recorded separately as MIG-001–004.

## 2. Make base composition explicit by role and construction generation

Do not subdivide base files merely to make more files. The existing
[tier assembly](../bases/tiers/source-gnu.nix) is already short and readable.

The native platform facts now live in `bases/source-gnu/platform.nix`, and `mkTier`
requires that platform explicitly. This extraction preserved the evaluated producer
identities. Construction-family adoption and retained adapter removal remain work.
Keep these responsibilities separate:

| Responsibility | Existing home and intended boundary |
|---|---|
| Generic base/environment contracts | `lib/owned-base.nix`, `lib/build-environment.nix` and `bases/tiers/default.nix`; validate and compose supplied providers. |
| Native platform/toolchain facts | `bases/source-gnu/default.nix` and `bases/tiers/default.nix`; isolate native GNU/Linux choices from generic contracts and package tables. |
| Ordinary provider choices | `bases/source-gnu/standard-tools.nix`; explicit named TVP selectors and explained cycle-breaking constraints. |
| Construction generations | `bases/tiers/source-gnu.nix` and `bootstrap/`; each stage selects its earlier compiler, tools and libraries. |
| Compatibility adaptation | `bases/tiers/construction.nix` and `fromLegacy`; bounded adapters until their real callers move. |
| Catalogue registration | Root `default.nix` and `bases/default.nix`; publish selected contexts and retained references. |

Move construction callers to the same family instantiation interface used by MPFR,
overriding base and dependencies before public evaluation. Keep construction
provider choices explicit. A tool building itself needs an earlier provider; a
lookup of its final public alias can create a cycle. Equal version numbers do not
establish equal compiler generations.

Preserve current compiler/libc/Binutils/tool identities during organization-only
changes. Base edits must rebind commands, provider metadata and attached tests;
unused tools must remain lazy. An earlier tier must not force the public tier it
constructs. `fromLegacy`'s package-name-based floor adaptation stays isolated from
ordinary named provider selection until its callers are gone.

Platform-specific provider selection belongs to the base/context. The current
concrete contexts are native x86_64 GNU/Linux. Additional architectures, cross
compilation and new compiler/libc combinations need explicit provider contexts
and qualification; flattening package indexes does not add that support.

## 3. Convert whole package families

Start with GMP, MPC and ISL. Together with MPFR they exercise the compiler's real
library and bootstrap dependencies. Then convert other libraries, build tools,
runtimes/profiles, and compiler, SDK and data entrypoints. Construction work can
move a necessary provider earlier in that order.
The next-family inspection identifies M4's explicit Gawk 5 selection as a
prerequisite to GMP's public dependency conversion. Resolve that build-only role
first, and coordinate construction-input activation so individual family rewrites
do not each rebuild the compiler chain. MIG-005 and MIG-006 record these boundaries
and the separate frozen-baseline decision.

For each family:

1. Replace layered/remapped definitions with complete `packageRecipes` records and
   a literal release table. Keep genuine compatibility constraints and patches.
2. Supply ordinary defaults with `mkFamily`; remove repeated constructor, platform,
   standard-tool, helper and test-context declarations.
3. Keep complete era builders at the package root. Group stable implementation
   facts in the builder and keep narrow release differences in recipe options.
4. Declare the source resolver and family assertions once. Reuse the existing
   assertions and runner, adapting only their binding to the effective package.
5. Convert every construction caller to explicit earlier-base/dependency
   instantiation. Preserve real user-facing profiles and their differences.
6. Delete obsolete `legacy.nix`, public/construction remapping and duplicate
   `native/`/`ordinary/` procedures only after checking their callers have moved.

This is a family-sized change, not a new task for every couple of versions.
Separate builders only at genuine procedure/interface eras. Helpers may be shared;
one versioned builder must not import or override another.

## 4. Verify the changed boundary and make progress visible

Capture before/after artifact, final, test, alias and construction identities for
the family. If they match, reuse the existing results. If only finalization changes,
reuse the artifact and test the changed final output. If only tests change, run the
changed tests against the cached package. Real compiler/dependency/procedure
changes require the corresponding build and consumer checks.

Use pure evaluation to check default resolution, edits and bootstrap direction;
use tiny fixtures for generic helper changes. Avoid rerunning the full catalogue
for an identity-preserving authoring rewrite. Keep failures and untested versions
visible rather than counting source cleanup as runtime qualification.

Extend migration status with a separate family-authoring view as this rollout
proceeds. Report adoption, construction callers still using compatibility paths,
split coverage and qualification independently. A `mkFamily` token alone is not
proof that a family's callers, builders or tests have been cleaned up.

Remove remaining adapters and old registration paths after the final caller moves.
Do not erase required seed providers, historical broken records, patches or real
profiles just because their implementation is old. Existing hardening, historical
failure and admission holds remain separate from this cleanup. Local iteration
continues on Tower with CI and NAS off.

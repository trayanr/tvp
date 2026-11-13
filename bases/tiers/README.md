# Construction base tiers

`import ./bases/tiers { inherit lib builder; }` provides `mkTier` and `fromLegacy`.
A tier selects a compiler, shell, standard tools and runtime providers. An earlier
tier constructs the next toolchain; the package recipe and owned constructor can
remain the same. `construction` records only the earlier tier's name.

`mkTier { name; previous ? null; compiler; shell; coreutils; ...; }` creates a native
x86_64 GNU/Linux owned context. A null previous tier declares an explicit seed
boundary. Other tiers name the earlier construction context.

`fromLegacy existingBase` adapts the exact selected compiler wrapper, libc and
floor to the owned execution interface. It creates no new derivations and exposes
no `stdenv` or `mkDerivation`. `construction.kind = "legacy-inputs"` records that
the selected input generations retain their original construction provenance.
This is not a claim that those providers were built by the owned protocol.

Retained Nixpkgs compiler/linker wrappers declare `suffixSalt`; the owned environment
selects their native host role so they consume the explicit include, link and hardening
flags. No setup script is sourced. Source-owned drivers keep their existing protocol.

Standard Make/Tar/archive/text roles come from the selected floor. Patchelf comes
from the base's existing fixup provider when available. Additional tools such as a
pinned construction Python are explicit `standardTools` overrides. The adapter
does not reach into the final public package set.

Use `base.override { standardTools.gnumake = earlierMake; }` for a named provider
replacement. `base.edit (inputs: inputs // { compiler = otherCompiler; })` edits the
complete input record and reconstructs validation and environment composition.
Both routes preserve declared construction provenance unless explicitly changed.

The catalogue exposes these concrete source-owned provider contexts as `tvp.baseTiers`:

| Tier | Compiler and construction role |
|---|---|
| `seed` | Existing GNU seed compiler/host runtime; constructs initial source tools and libraries. |
| `target` | Existing target driver with its selected libc/C++ runtime; actual input context used by the reduced native compiler construction. |
| `native` | Reduced native compiler and driver, constructed with the target context. |
| `full` | Complete compiler/driver, constructed with the native context; default for ordinary families. |
| `retained.<name>` | Exact earlier compiler/floor providers adapted for still-existing GCC13/GCC16 construction scopes. |

These are provider generations and can use the same GCC or MPFR source version.
The source-level construction remains declared in `bootstrap/`; naming a tier is not
a claim that every supporting package has been rebuilt or fully qualified.

A family exposes `.instantiate { version; base; deps ? {}; opts ? {}; }`. It overlays
base/dependency choices on definition data before constructing the selected package;
it never overrides an already-created final public package. MPFR uses this route for
compiler construction, locale inputs and retained MPC inputs, all through its one
owned procedure. Earlier standard tools come from the construction scope rather than
from the public base being built.

`tvp.builder.forBase base` returns source/output helpers with their tool defaults bound.
They remain ordinary named steps. Package `.edit` can replace the base and reconstruct
helpers/test contexts; `.editSteps` can replace, disable or insert named steps. No new
execution framework or ambient setup hooks are introduced.

# Compiler-family bases and construction stages

The public catalogue selects a compiler release and one of its actual stages:

```nix
tvp.bases.gcc_4.full
tvp.bases.gcc_9.full
tvp.bases.gcc_13.full
tvp.bases.gcc_16.seed
tvp.bases.gcc_16.runtime
tvp.bases.gcc_16.reduced
tvp.bases.gcc_16.full
```

Exact selectors follow package naming: `gcc_4_9_4`, `gcc_9_5_0`,
`gcc_13_3_0` and `gcc_16_2_0`. Major aliases select the latest registered release
within that major using version-aware comparison. `gcc_4` currently selects 4.9.4;
there is no `gcc_4_9` alias. `tvp.bases.default` selects `gcc_16.full`.
The selector describes the compiler release; the providers and Nix identities
identify its complete composition. There is no additional composition revision.

| Selection | Definition and construction role |
|---|---|
| `gcc_4.full` | GCC 4.9.4 source procedure, constructed with the earlier closed GCC16 full base. |
| `gcc_9.full` | GCC 9.5.0 source procedure, constructed with the earlier closed GCC16 full base. |
| `gcc_13.full` | GCC 13.3.0 source procedure, constructed with the earlier closed GCC16 full base. |
| `gcc_16.seed` | Source-bootstrap GNU compiler and host runtime. |
| `gcc_16.runtime` | Selected GNU target runtime with the earlier compiler, used to construct the reduced compiler. |
| `gcc_16.reduced` | Reduced native compiler and driver, constructed with the runtime context. |
| `gcc_16.full` | Complete compiler and driver, constructed with the reduced context; ordinary family default. |

GCC4, GCC9 and GCC13 expose only `full`. They have no separate owned seed,
libc, shell or reduced compiler builds. The old borrowed GCC13 ladder and its
wrapper-revision generations have been removed. Compiler version numbers do not
set construction order: an earlier available GCC16 context can build the source
of an older compiler release.

These are source-backed definitions, not runtime qualification claims. Source
preparation, evaluated plans and provider-origin checks do not prove that an
unbuilt compiler works. Compiler builds, installed controls and upstream results
remain separate receipts; incomplete or failed qualifications stay explicit.

## Provider construction

[The base entrypoint](../default.nix) resolves the selected system through
[platforms](../platforms/default.nix), registers release definitions and generates
aliases. Recipes do not repeat a platform selection. Native x86_64 GNU/Linux is
the current supported execution mode; adding another architecture requires actual
providers, recipe support and qualification.

[GCC4/GCC9 construction](../source-compiler.nix) selects complete source procedures
and explicit earlier libraries/tools. [GCC13 construction](../source-gcc13.nix)
uses its complete owned compiler procedure with the same closed source-GNU
predecessor. Each raw compiler has a genuine compilation artifact/final split;
[the shared source driver](../../bootstrap/source-full-gcc-driver.nix) binds the
resulting compiler, runtime, libc and Binutils. This code does not select Nixpkgs
compiler packages, host Bash/Coreutils or a Nixpkgs stdenv floor.

The GCC16 assembly reuses [the source-GNU stages](source-gnu.nix) and the explicit
[bootstrap ladder](../../bootstrap/default.nix). Its full-stage tool choices come
from the preceding local stage's `tools` record. Constructing a base must not look
back through public package aliases that depend on that base. Nixpkgs pure
`lib`/`config` values used by repository assembly do not supply executable providers.

## Tools and edits

`base.tools` is one lazy named provider catalogue. `tools.gcc` is the complete
selected driver; generic `compiler`, `shell` and `coreutils` are derived aliases.
The driver carries its Binutils/libc and runtime-directory protocol. A catalogue
entry alone does not add a tool to PATH: the execution baseline and active
helpers/steps contribute their selected providers.

```nix
base.override { tools.gnumake = otherMake; }

base.edit (s: s // {
  tools = s.tools // { gnumake = otherMake; };
})
```

An override merges named replacements. An edit transforms the selectable record;
copying `s.tools` retains other roles. Both reconstruct environment composition
and dependency tracking. Replacing `tools.gcc` selects a complete driver.
Independent Binutils/libc edits that disagree with that driver reject clearly;
metadata cannot rebind an executable wrapper. `standardTools` remains a temporary
compatibility input/view for older callers. New definitions use `tools`.

## Remaining recipe compatibility

[retained.nix](../retained.nix) publishes private compatibility records under the
four exact compiler keys. [compatibility.nix](../compatibility.nix) executes the
remaining stdenv recipes with the selected source-owned driver, Bash, Coreutils,
File and tool floor, using the repository's local vendored constructor. It does
not borrow a Nixpkgs stdenv or reconstruct the retired GCC13/v2/v3 producer graph.
The old construction variant set is empty.

`legacyEnvironment` checks this local stdenv view against its authoritative owned
base and exposes `.ownedBase` for migrated callers. A retained recipe body can
still use old authoring syntax; that does not make a foreign compiler acceptable.
New ordinary recipes use the public owned base and `tvp.builder.forBase`.
`fromLegacy` remains a compatibility helper for old callers and fixtures, not the
mechanism that supplies the current compiler providers.

Broken Readline 2.0 selects GCC9; ten broken Zlib 0.x releases select GCC4.9.
Those source defects and status records remain separate from compiler-provider
migration. GCC4.9 does not satisfy the Zlib records' GCC3.3-or-older requirement.

## Checks

`checks.source-base-providers` complements a source guard with evaluated checks
of the actual selected floor, driver, raw compiler A/F, predecessor and runtime
providers. Unknown bare production providers reject. This gate prevents a new
owned record from disguising a borrowed compiler or host tool set; it does not
certify compiler conformance or every optional upstream harness.

The existing eight shared base controls use `tests.forBase` with the effective
selected providers. Base/package execution tests, upstream suites and ownership
checks retain their own scopes. See [the authoring rollout](../../lib/AUTHORING-MIGRATION.md)
and [remaining-definition inventory](../../lib/LEGACY-DEFINITIONS.md) for the
remaining recipe-syntax and caller migration.

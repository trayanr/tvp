# Ordinary Autotools source migration

All 114 x86_64-linux ordinary Autoconf, Automake, Libtool and GNU Config
releases select source-GNU owned procedures with installed artifact/finalization
boundaries. This is source coverage only. The 77 migrated rows and 29
transitively changed compliant rows remain **UNCOMPILED / UNQUALIFIED**; evaluated plans and tiny helper fixtures do not
qualify their archive layouts, compiled outputs or upstream/consumer behavior.

Historical procedures are complete independent version-start files:

- Autoconf 2.10–2.13 uses environment configure bindings and shipped shell/Perl
  frontends. 2.50–2.64 has its own procedure. The 2.53–2.57 definitions retain
  Perl 5.24 and its recorded reason. Early macro/C-dialect and licence profiles
  remain definition data.
- Automake 1.0 has no aclocal or API-suffixed data. 1.2–1.5 retains environment
  bindings and unsuffixed data; 1.6–1.11 accepts configure arguments and installs
  API-suffixed data. Archive compression, header macros, aclocal availability,
  install directories and the 1.4/1.8 Perl patches retain their existing profiles.
  These procedures do not apply the modern configure-assignment API rewriter.
- Libtool 1.0–1.2 has no installed libltdl output repair. 1.3.5–1.4.3 and 1.5.26
  have independent libltdl procedures before LT_INIT. Early configure bindings,
  C89, the 1.4 Automake consumer pin and separate modern platform-script provider
  remain explicit. 2.6.2 retains its libtool-next-version interpreter preparation.
- GNU Config installs pristine scripts into its artifact. Runtime shell binding
  follows the split; its unchanged shipped harness runs in the independent suite.

The reviewed 2.65/2.72 Autoconf, 1.12 Automake and 2.2.10/2.4.7 Libtool
procedures and their shared output helper are unchanged. Eight compliant
Autoconf producer/artifact identities remain exact. The 25 compliant Automake
and four compliant Libtool identities necessarily change transitively: their
existing public latest Autoconf/Automake dependency selections now resolve to
the newly split 2.73/1.19 producers. No dependency version is upgraded or pinned
back to an unsplit producer to conceal this change. Retained legacy construction
recipes, bootstrap routing and non-native selection remain unchanged.

Historical releases reuse the existing consumer suites, fixtures, feature profiles
and test context/factory. Their independent make-check rebuild uses the historical
source's own check target, without modern Automake test-file selections or modern
Autoconf numbered-case assumptions. Modern releases keep the existing bounded
upstream factories. Production compilation/install and finalization consume none
of these test derivations, test results or test-only tools. Failures remain strict
suite failures. Logs, runtime behavior and upstream acceptance are deferred to
independent execution; no waiver or execution claim follows from this port.

The historical output helper retains the reviewed confinement, text-only prefix
relocation, hardlink separation and interpreter validation. `shipped` classifies
historical frontends by their actual shebang, accepting only shell/Perl; unknown
interpreters still fail. Runtime paths/interpreters and output repair happen only
after the split. The owned constructor enforces artifact-reference exclusion.

## Existing provider and File interfaces

Automake exports a pure `buildEnvironment` provider. Select it in an owned
consumer's `environment.tools`, with macro packages in `environment.libraries`.
Each package can publish `development.aclocalDirectories`; the default is its
`share/aclocal`. The base composes these into ACLOCAL_PATH. Explicit environment
overrides replace the composed value. No installed setup hook executes in the
owned builder. Automake still installs its legacy hook for compatibility consumers.
Upstream ACLOCAL_PATH, ACLOCAL_AUTOMAKE_DIR, AUTOMAKE_LIBDIR and `-I` behavior
remains available when invoking the installed programs directly.

File 5.48 and Libtool 2.6.2 also have independent ordinary owned recipes. File's
source-GCC prerequisite recipe remains separate and unchanged. The ordinary
File installs the compiled default magic database, shared/static libmagic and
its private compression development requirements. All four compression providers
are required and tested through the installed API and pipeline interface.

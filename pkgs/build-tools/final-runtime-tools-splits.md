# Final runtime tools: source boundary contract

Go 1.27.3, Node 26.13.0, Git 2.56.0 and Less 710 have source-only splits.
Compilation, installed behavior, emitted-layout guards and complete artifact-reference
exclusion remain **UNRUN / UNQUALIFIED**. This is not package runtime qualification.
Existing nonpasses, hardening limitations and strict classifier rules are unwaived.
One later coordinated latest validation remains required; full, machineReady and
mergeEligible remain false.

## Go 1.27.3

A prepares sources, runs production make.bash/cgo and installs the raw share/go tree
and relative public links. This version no longer exports the unconsumed legacy
GOROOT_FINAL. F copies the tree and checks paths without stripping or rewriting Go
program/build-ID bytes. Native executable-relative discovery retains public, nested
and symlink entry points and explicit user GOROOT.

Field classification: src/version/bootstrap, base, environment and construction tools
are A inputs. runtime.compiler/libc/loader/cc/cxx are genuine cgo compilation/default
inputs, with the existing compiler/libc/loader coherence rules. goOS/goArch and
dynamicLinker affect compilation. helperPython prepares source and checks F;
coreutils participates in installation/copy; binutils/patchelf are F path inspectors.
Final check edits reuse A. Release/hash, native platform and feature metadata stay
unchanged; older bootstrap/compiler ladders are untouched.

No consumer of installed-environment.json existed outside the old installation
command. Its immutable final observation now belongs to an independent installed
test directory, alongside its result. Build-provider and source-epoch receipts stay
raw. Existing standard-library, module and cgo factories still target F.

Later: emitted A exclusion, byte/build-ID equality, all GOROOT entry forms,
standalone runtime.GOROOT, modules and cgo loader/libc behavior.

## Node 26.13.0

A keeps full ICU/Temporal/SQLite/npm, production Ninja and raw install.py installation.
configurePrefix is an exposed context-free non-store build setting, default /tvp/node;
install.py still receives the explicit artifact prefix. process.config's node_prefix
therefore reports the stable configuration value. F copies, repairs known installed
text and the parsed config.gypi node_prefix field, then binds shebangs and performs
existing strip/RPATH/development/path operations. Builtin JS and snapshots are never
rewritten. Unknown structured prefix storage is rejected before writes.

Field classification: runtime.shell is compiled into child_process.js and legitimately
changes A; runtimeBash defaults through effective final. src/version/patches,
configurePrefix, compiler/base and environment.libraries (OpenSSL/zlib headers/link
providers) are A inputs. environment.tools and source Python/shell preparation are
construction inputs. runtime.libraries/dlopenDirectories select F lookup repair.
Coreutils copies F and installs A; toolPython prepares A and validates F;
binutils/patchelf select F repair. All declared inputs are exposed through final.
doCheck and the independent tests/upstream.nix factory affect validation only.

The four original tools/test.py cases retain release mode, timeout=120 and names,
using --shell=F/bin/node and prepared source/test data. Raw status/log capture is
separate from strict zero-status acceptance. doCheck=false records disabled/UNRUN,
not strict acceptance. A/F never consume those producers.

Later: emitted prefix exclusion, npm/node-gyp/addon behavior, declared-versus-final
prefix distinction, shell and existing ICU/crypto/zlib installed tests.

## Git 2.56.0

A uses construction Bash/Perl/Python for generators, stable configurePrefix=/tvp/git,
RUNTIME_PREFIX=YesPlease throughout make/install and DESTDIR staging. Upstream's
relative bin/libexec/perllib/template/etc interfaces remain. Native SHELL_PATH uses
a source-reserved NUL-marker slot; generator SHELL_PATH remains executable. Public
commands/templates remain production targets. Test-only all prerequisites move to
private validation, where test-tool and its library prerequisites are constructed.

F copies the installed tree, requires A bytes to be absent, validates all native
slot owners and binds only declared slots and interpreter text before existing
shebang/strip/RPATH checks. Internal hardlinks survive. Full-path text boundaries
cover generated interpreter fallback text as well as directives; native fallback
prefix stays stable. No broad native prefix replacement is used.

Field classification: src/version/base/configurePrefix, compiler/headers/linked
libraries and environment are A inputs. bash/perl/python are exposed construction
providers; their effective defaults feed runtime.shell/perl/python. Independent
runtime interpreter edits are F-only. runtime.libraries/dlopenDirectories are F
lookup inputs. helperPython prepares guarded source and validates F; Coreutils
installs/copies; binutils/patchelf inspect/repair F. doCheck/upstreamPreparation are
validation-only. Rust/Cargo and all feature/provenance declarations remain.

The unchanged t0000/t0008/t1300 cases run privately against GIT_TEST_INSTALLED=F/bin,
with explicit test shell and prepared templates/test-tool. Raw statuses/logs remain
separate from zero-status acceptance. The existing sandbox/setgid t0001 limitation
remains excluded and unwaived; no compatibility observation becomes strict success.

Later: emitted slot owners/counts, hardlinks, empty-PATH direct/libexec calls,
exec-path/templates, shell aliases/ENOEXEC, Perl modules/Python and HTTP tests.

## Less 710

A retains configure/build/install and declared-shell interposition with its reserved
shell[] slot. artifactName=pname-version gives equal-width A/F roots. F copies and
preflights the whole namespace, native sections and exact source-defined constants
before writing changed bytes/links. readonly path strings and decode.c's exact
writable LESS_OSC8_OPEN_ANY byte-table record have separate policies. Equal width
preserves offsets/lengths; unknown strings/owners are errors, not waived layouts.
F binds the shell slot, shebang and less-osc8-open's actual own-bin PATH, then keeps
existing strip/RPATH checks. No launcher or arbitrary native rewrite is introduced.

Field classification: src/version/patches, base/compiler/configure settings,
construction bash and ncurses/pcre2 headers/link choices are A inputs. bash is
exposed and runtime.shell defaults through final; independent runtime.shell and
runtime.libraries are F-only. python prepares A and validates F, Coreutils installs
and copies, binutils/patchelf inspect/repair F. Perl and Diffutils are test-only.
User LESSECHO/lesskey/OSC8 overrides and all command features remain unchanged.

Independent validation replays preparation/configure, builds distinct LESSTEST
*.t.o/less_t and lesstest driver products, then retains runtest -e -l ../less_t lt's
raw log/status. Its strict acceptance never gates A/F.

Later: emitted readonly/table shapes, slot counts, A exclusion, helper/shell status
and signal behavior, lesskey/lessecho defaults/overrides and independent LESSTEST.

## Source checks

lib/tests/final-runtime-tools.nix selects exactly these four recipes for inventory,
producer identity/reuse, output transport and factory-registration contracts.
lib/tests/final-runtime-tools.py checks shell syntax and actual recipe-selected copy
and standalone store-file finalizers using tiny invented byte/ELF fixtures. Its
explicit fixture edits select already-cached Python/Coreutils/readelf helpers;
canonical providers are not built or executed. Fixtures cover hardlinks, relative
links, raw Go-byte preservation, Node's parsed metadata field, Less's byte table,
reserved slots and reject-before-write controls. They do not prove emitted layouts.

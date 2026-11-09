# Opt-in GNU consumer hardening

This is a consumer adapter for the existing native x86_64 GCC 16.2/glibc
selection. It constructs small launchers, selects a separate `ld` launcher, and
links all other Binutils commands to the existing tools. It never edits or
rebuilds the retained compiler, embedded driver, runtime, or Binutils. The
ordinary source base and package aliases remain unchanged.

```nix
candidate = import ../. { };
hardened = candidate.withHardening {
  defaults = [ "bindnow" "fortify" "format" "pic" "relro"
               "stackprotector" "strictoverflow" ];
  disable = [ "format" ];
};
pilot = tvp.canonical.zip_3_0.override { base = hardened; };
# Existing recipe hardeningDisable is subtracted by the recipe command, after
# owned-build's default preamble. Both .override and .edit remain effective.
exception = pilot.edit (spec: spec // {
  hardeningDisable = [ "format" "fortify" ];
});
```

`lib/hardening-policy.nix` is pure. `defaults`, `enable`, and `disable` are lists
of supported names; selection is `(defaults union enable) minus disable` in
canonical supported-name order. Disable wins. Unknown names/types/attributes
fail; PIE is deliberately unsupported. Empty selection returns the exact old
base object, preserving rendering and producer identities. The returned base
supports existing `base.override`, environment overrides, recipe overrides,
edits and output projections. No generic environment or runner protections are
weakened. The adapter's `hardeningPolicy`, `defaultHardeningFlags`,
`underlyingDriver`, `underlyingBintools`, `libc` and `runtimeDirectories` are
inspectable. Its `bintools` selects the small linker adapter output; it does not
replace the old Binutils producer. Both adapters declare their driver/Binutils,
Python and validated policy inputs explicitly and retain `.override`/`.edit`. The explicit Python interpreter is the
candidate's existing source-built `tools.python`.

The owned preamble supplies `NIX_HARDENING_ENABLE` from the selected adapter.
An existing recipe can subtract its `hardeningDisable`, or explicitly set a
supported selection in its command after the preamble. Outside a prepared step,
an absent selection uses the configured defaults; an empty value disables all
protections. This is a defaults policy, not a mandatory enforcement boundary:
recipes can explicitly request any supported name, including a previously
disabled one. Unknown runtime names fail. The adapter consumes this selection
before entering the unchanged driver, which still rejects nonempty requests.
With an empty runtime selection it passes the old argv and flag protocol through
unchanged (and removes only the empty selection).

For an active policy the adapter decodes the existing whitespace-free ordered
flag arrays without shell interpretation. Compile/link ordering is: protection
defaults, `NIX_CFLAGS_COMPILE`, then `NIX_CFLAGS_LINK` for link invocations, then
caller argv, then `NIX_LDFLAGS` encoded as `-Xlinker` pairs. It expands nested GCC
response files for inspection and forwards that flattened argv exactly once,
removing the three consumed environment variables. The unchanged driver receives
no second policy and no second environment contribution. GCC's own internal
linker remains raw Binutils, with the requested linker arguments already passed
by GCC. Selected direct `LD` calls enter the adapter's separate `ld` launcher:
link defaults, `NIX_LDFLAGS`, then caller argv. Other compile/link environment
flags do not apply to direct ld. Direct ld never implies compiler protections.

| Name | Selected behavior |
| --- | --- |
| bindnow | `-Wl,-z,now` (direct ld: `-z now`) |
| relro | `-Wl,-z,relro` (direct ld: `-z relro`) |
| pic | `-fPIC`; no executable PIE promise |
| stackprotector | `-fstack-protector-strong` |
| strictoverflow | `-fno-strict-overflow` |
| format | `-Wformat -Wformat-security -Werror=format-security` |
| fortify | `_FORTIFY_SOURCE=2` only with effective optimization above zero and no explicit `-D`/`-U` for that macro |

This follows the selected glibc `features.h`: fortification requires
`__OPTIMIZE__ > 0`. Default optimization and effective `-O0` receive no fortify
macro and no invented optimization level. Last optimization wins across the
ordered environment/argv/nested responses. Explicit macro definitions or
undefinitions are respected, including level zero; the adapter adds no competing
macro. Later caller options can override the other defaults as well.

Queries (including effective specs) retain old output and receive no protections;
`-###` remains a dry-run compilation, showing the actual flags. Compile,
preprocess, syntax-only and assembler-output modes receive no linker flags.
Assembler inputs/language modes receive no compile protections. Shared/PIC
consumers are supported. Static and relocatable links receive no dynamic linker
protections, including recognized raw `-Wl`/`-Xlinker`/environment spellings.
No dynamic-property claim applies to those artifacts. Existing ABI and static
PIE rejection remains. Direct ld's static/relocatable handling is conservative:
any explicit static selection suppresses these defaults even if followed by a
dynamic selection. Caller arguments still retain their actual linker semantics.

Active-policy inspection rejects unreadable/deep/malformed response files,
unknown optimization spellings, and opaque specs/plugin/preprocessor interfaces
(`-specs`, `-wrapper`, `-fplugin`, `-Wp,`, `-Xpreprocessor`, `-imacros`). GCC
response escaping follows libiberty's grammar, including backslash inside quotes;
this is not shell quoting. Normal headers can still redefine macros; the adapter
cannot certify arbitrary source, custom pragmas, linker scripts, language
frontends, or unrecognized GCC extensions. Mixed assembler/source invocations
conservatively omit compile defaults. These bounded native tests are neither a
portable security guarantee nor full GCC conformance. Callers can select the
original base for unsupported cases.

`pilots.nix` constructs only Zip 3.0 and Unzip 6.0 with their public `.override`
seam. Their existing `format` exception remains effective. Their sources,
procedures, dependency selections and test contracts are retained. These are
check-only opt-ins, not catalogue variants. `checks.source-gnu-hardening` covers
policy composition, overrides/edits/projection, fake argv/injection controls and
real C/C++/shared/direct-link/static/relocatable controls; installed archive
checks are separately selected through the existing test factories. Their known
zipnote crash and Unzip stale upstream fixture remain nonpasses. HARDENING-GATE-1
stays open until ordinary activation and accepted assembled-wave qualification.

# Older Perl split design experiments

These are standalone experiments, not production recipes or a finalization API.
The nine older ordinary Perl releases remain on their original procedures. No
split-baseline rows have been removed, and Perl 5.44.0 is unchanged.

The owned builder normally names its installed prefix `perl-VERSION-artifacts`
and its final output `perl-VERSION`. Their store prefixes differ by ten bytes. All nine
upstream Configure scripts reject combining `userelocatableinc` with `useshrplib`.
Retaining shared libperl, XS and embedding therefore requires another design.

`source.py` is a candidate preparation operation with explicit caller-selected
contracts. It validates canonical parents, the complete source tree, contained
hardlink groups, selected full UTF-8 text, frontends, original patch contexts and
tool availability before writing. It does not dispatch on versions. Configure
and the Linux hint are the only selected shell frontends; other platform hints
are preserved. `guards.py` exercises rejection before writes and preservation of
an internal hardlink. Source preparation is separate from the ELF experiment.

`elf.py` is a read-only native ELF section/offset/string inventory. It requires
successful declared readelf inspection. It does not establish that code or
relocations cannot hold interior pointers into pooled strings.

`run.py` copies one explicitly supplied, already-valid cached Perl into disposable
canonical temporary roots. It never builds a Perl or realizes a missing output.
Every old-prefix ELF occurrence is mapped before copy mutation. The experiment
only edits installed-library strings starting at NUL boundaries in read-only
`.rodata`; RPATHs go through declared patchelf. Known Config/header/packlist
metadata must be text, even if corrupted with NUL. It checks every regular file
and symlink target for the old prefix. The copied outputs are deleted on exit.
Raw command stdout/stderr and small fresh XS/embed witnesses remain in the
explicit evidence directory.

On the cached retained 5.42.3 output, an equal-length rebase passed bare `@INC`,
Config paths, List::Util XS, fresh MakeMaker XS and shared-libperl embedding
(including `DT_NEEDED`). A ten-byte-shorter rebase with trailing NUL padding
excluded every old-prefix byte but put ten NUL bytes in each bare `@INC` entry.
List::Util lookup then failed with exit 2. This is a negative experiment, never a
proposed safe binary replacement operation.

The source of `S_incpush_use_sep` explains the failure: normal builds pass literal
lengths through to `incpush`. All nine sources have a separate
`PERL_RELOCATABLE_INCPUSH` compile-time hook that switches to `strlen`, explicitly
leaving binary relocation tooling to the distributor. The cached interpreter
does not prove that hook, shortened-string pooling semantics, or its effect on
shared embedding and fresh XS in any newly built representative.

The specification can now opt into equal-length prefixes with
`artifactName = "${final.pname}-${final.version}";`. Artifact and final derivations
keep different hashes and do not capture the final path during compilation.
The constructor fixtures in `lib/tests/recipe-splits.nix` exercise the real
single-output and named-output shape, artifact reuse, and default identity
preservation. The cached equal-length experiment supplies limited shared-Perl
behavior evidence for that shape; it does not prove every new release.

A guarded production finalizer for Config/CORE/packlist metadata and the compiled
library strings is still required, followed by the five source-built
representatives. Do not adopt an unsplit recipe, drop shared mode, mask lookup
through the environment, or count these experiments as a completed migration.

To reproduce, supply a JSON configuration with `cache` and absolute selected
`tools.cc`, `tools.make`, `tools.readelf`, `tools.patchelf`, `tools.cp`, and
`tools.chmod`. Invoke the selected Python with `-B run.py CONFIG EVIDENCE_DIR`;
the evidence directory must already exist. `guards.py` additionally needs
`shell`, `diff`, and `pwd` pointing to declared executable store files. No
environment discovery, network access, compiler bootstrap or Nix settings change
is involved. Fresh fixture compilation uses at most two Make jobs.

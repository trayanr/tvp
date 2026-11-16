# Libxml2

All 69 public releases use the same family API, literal release records and
artifact/final splits. [AUTHORING.md](AUTHORING.md) describes the complete era
procedures, independent upstream consumers and earlier bounded receipts.
Construction callers instantiate that family with explicit earlier inputs;
duplicate old indexes, stdenv builders and caller factories are removed.

The source eras retain their real interfaces:

- 2.7 has no LZMA; XPath begins at 2.7.7.
- 2.8 adds linked LZMA and shared/static defaults; 2.9.5 changes the C dialect.
- 2.10 changes the static default and upstream check flow.
- 2.13 changes the HTTP default; 2.14 changes the shared-library ABI.
- 2.15 removes the LZMA implementation; HTTP remains only an ABI option.
- 2.15.4 retains its distinct native installed and known-corpus profile.

Python bindings remain disabled, ICU defaults off, and iconv uses the selected
libc. Zlib and linked LZMA remain explicit TVP dependencies where applicable.
Standard tools follow the effective base. Runtime XZ edits affect installed
linkage assertions independently of the construction provider.

Historical profiles keep a compiled-tree checkpoint in A. F drops that checkpoint
and repairs installed output. Independent U restores the tree and captures raw
upstream evidence; its classifier remains separate from production. The latest
native upstream route reconstructs a private source tree. The shared
`ordinary/elf.py` remains active because compiler/libc helpers also import it.

Known RNG/XSD nonpasses, corpus/feature gaps and source/report binding limits
remain unwaived. A passing known-corpus compatibility receipt is not strict XML
conformance. Private normative/observation prototypes do not modify the current
release sources. Earlier results apply only to their bound producer identities;
the current source/tool cleanup does not requalify changed outputs. Hardening and
broader admission holds remain separate; CI/NAS remain off.

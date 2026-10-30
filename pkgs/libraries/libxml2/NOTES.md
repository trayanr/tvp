# libxml2 checks

2.15.4 needs pkg-config in its generated configure script, including with explicit
dependency paths. Its separate builder pins pkg-config 0.29.2. Earlier recipes and
existing consumers keep their inputs.

The shared suite checks installed headers, version reporting, DTD validation,
compression, pkg-config and XPath. Additional upstream checks were run for 2.15.3
and 2.15.4 with the normal build profile and pinned W3C XML test data. Both complete
`make check`, but its successful exit hides seven identical Relax NG corpus
mismatches: the runner does not count or propagate those incorrect-schema failures.
This is not a strict conformance pass.

The bounded `relaxng-corpus` test covers only those two reviewed releases:

- Five old cases reject U+0E35 at the start of a name. The implemented
  [XML Fifth Edition profile](https://www.w3.org/TR/2008/REC-xml-20081126/#NT-NameStartChar)
  accepts it. Matching instances pass; leading U+0301 and wrong-name/namespace
  controls fail as required.
- `datatypeLibrary="foo:"` follows the intentional
  [RFC3986 migration](https://github.com/GNOME/libxml2/commit/d7af555327843a9938a913205ac703c13c225603).
  The 2001 Relax NG text still names RFC2396, so this remains a historical profile
  divergence. Relative URIs, fragments and malformed escapes are rejected.
- A wildcard attribute inside `choice` incorrectly compiles without repetition,
  contrary to [Relax NG §7.3](https://relaxng.org/spec-20011203.html#attribute-restrictions).
  This shipped schema-checking defect is recorded as XFAIL, with direct-wildcard,
  finite-choice and repeated-wildcard controls. It is not a demonstrated failure
  validating a correct schema. The relevant
  [2019 change](https://github.com/GNOME/libxml2/commit/ea695ac0d608e79ce7b86804bab64565e85a8866)
  explains the guard; no first affected release range is claimed.

Compatibility results and strict-conformance failures remain separate in each test
output. Unexpected changes, including a possible fix to the historical defect,
fail the baseline check and require review. No runtime backport or disabled feature
is introduced; `degraded` metadata would misdescribe this faithful upstream build.

Runtime evidence is native x86_64 Linux. Missing XSTC corpora, disabled Python
bindings, long-running limits tests and sanitizer/fuzz campaigns are not covered.
Upstream's catalog/thread test has a weak document-existence oracle; its passing
exit is not evidence that nested entities resolved correctly.

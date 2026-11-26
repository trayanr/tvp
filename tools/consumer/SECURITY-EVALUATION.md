# Live audit candidate evaluation

On 2026-11-26, both adapters were run against the same 14 public controls: one
upstream-affected and one upstream-fixed version for seven package families.
Grype 0.122.1 was built from source with TVP Go 1.27.3. No CI job was added or run.

That is the provenance of the historical run below. The current `tvp` command
instead bundles `pkgs.grype` from TVP's locked `nixpkgs` input.
Grype is no longer a TVP catalogue family. This dependency change does not alter
the recorded comparison or imply that it was run with the currently selected
scanner version. OSV still uses its public HTTPS API directly.

After switching dependencies, Grype 0.122.0 from Nixpkgs revision
`2786a2a72088ecf32aea5b3ec52099e6a7cff78f` replayed the same 14 controls offline
against the retained database: all seven affected targets were detected and all
seven fixed targets were absent. This compatibility replay does not replace the
original two-candidate comparison or its provenance.

**Grype is the default for the current TVP package scope.** OSV remains available
with `--backend osv`. This small matrix establishes useful initial behavior;
it is not a catalogue-wide coverage claim or an application exploitability test.

## Target advisory results

Each cell lists the affected control followed by the fixed control. “Absent”
means the named target advisory was absent; fixed controls can still match other
advisories. Expected results come from the linked upstream advisories, not from
either scanner's output.

| Family and affected → fixed versions | Target advisory | Grype | OSV |
| --- | --- | --- | --- |
| Ruby 3.0.6 → 3.0.7 | [CVE-2024-27282](https://www.ruby-lang.org/en/news/2024/04/23/arbitrary-memory-address-read-regexp-cve-2024-27282/) | Detected / absent | Missed / absent |
| OpenSSL 3.0.5 → 3.0.7 | [CVE-2022-3602](https://openssl-library.org/news/secadv/20221101.txt) | Detected / absent | Detected / absent |
| PostgreSQL 16.4 → 16.5 | [CVE-2024-10979](https://www.postgresql.org/support/security/CVE-2024-10979/) | Detected / absent | Unsupported / unsupported |
| PHP 8.2.17 → 8.2.18 | [CVE-2024-2756](https://github.com/php/php-src/security/advisories/GHSA-wpj3-hf5j-x4v4) | Detected / absent | Missed / absent |
| Bundler 1.17.3 → 2.5.11 | [CVE-2021-43809](https://github.com/ruby/rubygems/security/advisories/GHSA-fj7f-vq84-fh43) | Detected / absent | Detected / absent |
| Curl 8.3.0 → 8.4.0 | [CVE-2023-38545](https://curl.se/docs/CVE-2023-38545.html) | Detected / absent | Detected / incorrectly matched |
| libxml2 2.12.4 → 2.12.5 | [CVE-2024-25062](https://discourse.gnome.org/t/libxml2-2-12-5-released/19337) | Detected / absent | Detected / absent |

Grype detected **7/7 affected controls**, with **0/7 target matches on fixed
controls**. OSV detected **4/7**, missed two, and had no declared PostgreSQL query
identity. It also matched the Curl target against the upstream-fixed control.
Unrelated advisory findings were retained and were not counted as false positives.

Ruby, OpenSSL, PostgreSQL, PHP, Bundler and libxml2 profiles and versions came from
actual TVP canonical package metadata; their derivation paths were recorded without
building the packages. Curl's two historical versions are explicitly labelled
upstream version controls, using the current family's identity profile. They are
not claimed as existing TVP packages or realized builds.

## Findings that changed the implementation

- Grype's current JSON wraps database status under `descriptor.db.status` and
  includes provider provenance. The adapter now accepts that shape and retains
  both status and provider evidence, while keeping older flat status compatible.
- Curl's output includes both the command and libcurl. Declaring only `haxx:curl`
  missed the target advisory on `haxx:libcurl`. TVP now declares both CPEs, and
  the adapter scans them without duplicating package findings.
- A separate native-package coverage probe showed that a generic PURL without
  a declared CPE could return no useful matches for known-affected Curl. That
  incomplete identity is now reported as unsupported, rather than counted as
  successful native advisory coverage.
- OSV Git queries need release-specific identities. TVP owns exact Ruby,
  OpenSSL, PHP and libxml2 tag mappings. Profiles are bound to their declared
  version; an override cannot silently reuse a stale tag.
- TVP's ImageMagick version spelling (`7.1.1.36`) differs from upstream
  (`7.1.1-36`). The family supplies that exact upstream version using its existing
  source-tag conversion; scanner inputs normalize it while reports retain the
  original TVP version. libffi, libxslt and zlib also have TVP-owned CPE profiles.
- OSV's converted Curl CVE record included `curl-8_4_0` among affected versions,
  contradicting the upstream advisory's fixed boundary. Exact tag queries
  reproduced the discrepancy. No hidden per-CVE suppression was introduced.

PostgreSQL's PL/Perl and libxml2's Reader/DTD/XInclude conditions illustrate why
these remain advisory matches with applicability unassessed. Version controls do
not establish which vulnerable features are enabled in a particular build.

## Evidence and repetition

The evaluator writes immutable matrix, source snapshot, component, result/error
and comparison files to a new output directory. It records scanner/database
evidence and scores the target ID and its declared aliases. A backend failure or
unsupported component cannot become a passing control.

```sh
nix shell --inputs-from . nixpkgs#grype .#python_3 --command python3 -B \
  tools/consumer/evaluate_audit.py --tvp . \
  --output /absolute/new-evidence-directory --cache-dir /absolute/advisory-cache
```

This command uses Grype from the current `nixpkgs` pin. Treat its output as
a new comparison and retain its own scanner version, source snapshot and
database/provider evidence. Use `--offline` and a new evidence directory to repeat
using a compatible retained cache.
The matrix digest for this run was
`d6934a5a7557e5398ee9b31e66b38c396a7ea7db39a6f3d2d6a9f98a19ec85e4`.
Grype reported DB schema `v6.1.10`, built `2026-11-26T06:22:34Z`; the OSV response
set digest was `679a25f417dc40af53eef98f7c8b31ea2318a660ae2e1da300491caaaabc3af4`.
OSV data is a captured query-response set, not a complete database snapshot.

Observed elapsed times were 8.5 seconds for Grype and 11.9 seconds for OSV, with
Grype's database already downloaded and four OSV queries cached. These timings
are not cold-start benchmarks. Repeat this matrix when scanner or advisory data
changes and extend it before claiming broader detection coverage.

# Local batch receipt collection

`tvp-test report --manifest batch.json --output batch-report.json
--summary batch-report.txt` collects an explicit index of local evidence. The
summary is optional. Python callers can use `batch_report.collect(manifest_path)`
and `batch_report.publish(report, output, summary_path=None)`.

This command reads files and writes the requested report. It never calls Nix,
queries store validity, builds, starts/waits/verifies latest, roots outputs,
contacts services, or publishes anything. No dependencies or operator activation
are needed. An already saved `latest verify` observation can be supplied; this
command does not refresh it. Historical receipts stay unchanged.

## Manifest and envelopes

JSON objects reject duplicate keys, extra envelope fields, and nonfinite numbers.
All references hash the exact bytes parsed with the verifier's strict object
loader. Hashes use lowercase hexadecimal SHA256. The manifest's source identity
has exactly `path`, `revision`, `tree`, `narHash`: a normalized store source path,
full Git commit and tree IDs, and a SHA256 SRI NAR hash. Obtain these externally
from CLI Git-normalized `nix flake metadata --json --no-write-lock-file` on the
clean committed checkout and `git rev-parse HEAD HEAD^{tree}`. The collector
checks supplied identity bindings; it cannot independently establish their truth.
A raw getFlake/path snapshot is not that source authority.

A minimal manifest (substitute actual identities and the envelope's byte hash):

```json
{
  "schema": "tvp.batch-manifest/v1",
  "subject": {
    "path": "/nix/store/00000000000000000000000000000000-source",
    "revision": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    "tree": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
    "narHash": "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
  },
  "scope": {"families": ["zip", "unzip"], "description": "Archive receipt collection"},
  "references": [
    {
      "id": "focused-archive", "kind": "focused", "path": "focused.json",
      "sha256": "REPLACE_WITH_EXACT_ENVELOPE_SHA256",
      "subject": "REPLACE_WITH_THE_SUBJECT_OBJECT_ABOVE",
      "scope": {"families": ["zip", "unzip"], "description": "Archive receipt collection"},
      "lineage": []
    }
  ]
}
```

Every indexed envelope has exactly `schema: "tvp.batch-evidence/v1"`, `kind`,
`subject`, `scope`, `claims`, `artifacts`. Its kind/subject/scope must equal the
reference. Scope has a nonempty unique list of `families` and a `description`;
reference families must be a subset of the selected manifest families. This binds
the declared scope; it does not prove that a historical artifact covered it.

`artifacts` is an explicit list of `{path, sha256, format}` objects. Format is
`json` (strict parsing) or `bytes` (hash only). Relative reference paths resolve
against the manifest directory; relative artifact paths resolve against their
containing envelope directory, including latest observation paths. Absolute paths
are permitted. There is no directory discovery or historical schema inference.
Evidence-only adapters can normalize immutable historical receipts by naming the
original files here, copying their claims honestly, and stating adapter limits.
The report preserves the envelopes and exact original input hashes. It does not
interpret arbitrary artifact contents as proof or approval.

## Typed claims

All fields below are required; unknown fields fail. Lists can be empty unless
specified otherwise. Named records are `{id, status, detail}`, with unique IDs.
Status is one of `PASS`, `FAIL`, `XPASS`, `SKIP`, `ABSENT`, `QUALIFIED_NONPASS`,
`ACTIVE`, `PARTIAL`. Raw statuses and details are retained without conversion.
Use qualifications for unavailable upstream suites, raw failures, stale fixtures,
and scoped availability successes alongside their nonpass limitations.

| Kind | Exact claims fields |
| --- | --- |
| `focused` | `status`, nonempty `records`, `limitations` (string list) |
| `review` | `status` (`COMPLETE`/`PARTIAL`), `findings` (`{id, detail}` list), `limitations` |
| `resolution` | `review` (reference ID), `finding` (finding ID), `status` (`RESOLVED`/`UNRESOLVED`), `detail`, nonempty `proofs` (focused reference IDs) |
| `qualification` | `records`, `openGates` (string list), `limitations` |
| `latest` | `status`, `terminal` (boolean), `workerActive` (boolean), `observation` (`{path, sha256, format: "json"}`), `limitations` |
| `lineage` | `from`, `to` (source identity objects), `mode` (`repair`/`proof-reuse`), nonempty `proofs` (focused IDs), `resolutions` (resolution IDs), `reason` |
| `protection` | `domain` (nonempty name), nonempty `files` (`{path, sha256}` list, absolute paths) |

Latest observations must be saved `tvp.latest-verification/v1` JSON with matching
`result`, subject source/revision/tree, snapshot path/revision/locked revision and
NAR, and explicit `full=false`, `machineReady=false`, `mergeEligible=false`.
The complete observation is retained. Failed/partial/active claims or a
nonterminal/active worker remain unresolved, even with an availability PASS.
These flags remain evidence claims, not independently observed worker state.

Protection domains retain their own absolute paths and hashes. For example,
`old-dirty` and `clean-source` may name different bytes for README.md. Neither is
compared with the other's literal or used as a source identity substitute.

## Repairs and proof reuse

Every reference must bind the final manifest subject, or carry an ordered
`lineage` list of lineage reference IDs linking its earlier subject to that final
subject. Each step has exact `from`/`to` identities, covers the evidence families,
and names passing focused proof claims at `to`. Intermediate proofs and lineage
envelopes themselves need a complete onward chain. Cycles and gaps fail. These
are explicit provenance assertions, not a way to establish runtime equivalence.

A repair step also requires explicit resolution references. Each resolution names
an actual finding of a review at `from`, binds `to`, covers the affected scope,
and names passing focused proof claims at `to`. Resolutions themselves always
bind the final manifest subject; use proof-reuse for earlier intermediate steps.
Finding IDs are local to a review; resolutions use the pair `(review, finding)`.
Unknown or duplicate resolutions fail. Unresolved findings and raw nonpasses stay
visible even when other proofs or lineage claims are supplied. An unresolved
resolution can record passing partial repair evidence without closing the finding.

## Results and immutable outputs

`observed.inputs` records verified byte hashes; `observed.referenceBindingsChecked`
records structural identity/scope binding checks. `claims` and `latestObservations`
contain supplied assertions, not collector-certified execution. Hash agreement
never certifies freshness, conformance, security parity, or review authenticity.

`COLLECTED` means all selected families have focused, review, qualification and
latest references without reported nonpasses or unresolved findings. `INCOMPLETE`
lists missing family/kind pairs. `UNRESOLVED` preserves nonpass/partial/active claims,
open qualification gates and unresolved findings; missing receipts remain listed
as well. These states describe collection only. Exit 0 means collection and
publication succeeded, including INCOMPLETE/UNRESOLVED; malformed bindings, changed
inputs or output conflicts return nonzero. No state is an admission PASS.

`machineReady`, `mergeEligible`, `full`, and `freshExecutionCertified` are always
false. Caller approval fields are rejected. HARDENING-GATE-1 always remains open
and unwaived in the report, including COLLECTED. It is a separate migration gate,
not a receipt collection requirement that this command can satisfy.

JSON is deterministic for the same manifest, resolved input paths and bytes.
Publication uses the verifier's atomic no-clobber report writer and rechecks all
input hashes. Identical repeats preserve existing evidence; conflicting JSON or
summary rejects. Output aliases of inputs or each other fail. The optional text
summary includes the JSON byte hash, claims and limitations. Each output is
published atomically, with both conflicts checked first; the pair is not a
filesystem transaction. After an interruption between publications, repeat the
same command to create the missing summary. A concurrent conflicting writer can
cause a nonzero exit with the first output already published; it is never replaced.

# 0019: The declared `spec_rows.5` set is eleven, not nine

- **Status**: ratified, effective when the PR for issue #108 merges
- **Supersedes**: the two counts in decision record
  [`0011`](0011-corner-verification-pvt-grids.md) §5 ("The declared row set is
  the spec's electrical rows, gaps included") — the declared set is
  **eleven**, not nine, and the post-gap remainder is **seven**, not five.
  Nothing else in §5 or anywhere else in 0011 is affected, and 0011 is not
  rewritten (`TEMPLATE.md`: "Do not rewrite a ratified record; supersede it")
  and keeps its own status line.
- **Date**: 2026-11-19
- **Decided by**: Loom Builder agent, issue #108
- **Numbering note**: `0019` checked free at branch time (2026-11-19): the
  highest record on `main` is `0018`, and the only open PR then adding a
  decision record (#95) adds
  `0015-item1-netlist-freshness-gate.md`. `0003`–`0005` are sibling-repo
  records and are not reused (see 0011 §Numbering).

## Context

0011 §5 reports the size of the `spec_rows.5` declared set as nine, twice: it
says the manifest "declares eleven minus two" (subtracting the Area and
Signoff rows) and later counts "of the remaining five" rows after four gaps.
The manifest declares **eleven** (measured 2026-11-19, against the tree this
record lands on):

```console
$ jq '.spec_rows["5"] | length' manifests/sg13cmos5l-bandgap.json
11
$ jq '[.spec_rows["5"][] | select(has("gap"))] | length' manifests/sg13cmos5l-bandgap.json
4
$ jq '[.spec_rows["5"][] | select(has("gap") | not)] | length' manifests/sg13cmos5l-bandgap.json
7
$ jq -r '.spec_rows["5"][] | select(has("gap")) | .id' manifests/sg13cmos5l-bandgap.json
vref_untrimmed_line_3sigma
vref_trimmed_line
trim
supply
```

The subtraction is the error. `spec/target-spec.md`'s row-id table has eleven
rows, of which Area and Signoff carry no row id (`—`) — they are already
excluded from the id expansion, because their binding conditions are a layout
cell and the DRC/LVS/ERC decks, which T1 items 2, 3 and 4 grade. The table's
remaining nine id-bearing rows expand to **eleven** ids: `Temp coefficient`
carries two (`tc_endpoint`, `tc_box`) and `Startup` carries two
(`startup_self_starting`, `startup_time`). Subtracting Area and Signoff from
the eleven again therefore yields a nine that no quantity in the manifest
has. (The three `Output reference` entries are three distinct table rows
carrying one id each — `vref_nominal`, `vref_untrimmed_line_3sigma`,
`vref_trimmed_line`.)

The second count follows from the first: 9 − 4 = 5, but §5's own enumeration
immediately after — six rows covered by passing citations plus one,
`psrr_dc`, covered by a citation that **fails** its ratified Target (§2) —
sums to seven, which is the manifest's own figure:

```console
$ jq '[.. | objects | select(has("failed_rows"))][0].failed_rows' \
    manifests/sg13cmos5l-bandgap.signoff.json
[
  "psrr_dc"
]
```

Every other statement in §5 is correct and stands: the exclusion of Area and
Signoff, the four declared gaps, `psrr_dc` failing, `uncovered_rows` empty,
and item 5 grading `unmet` / `check_failed`. No bound, row, criterion, status
or grade depends on the denominator — the error is in descriptive prose only.

## Decision

The declared `spec_rows.5` set is **eleven**: of those, **four** are gaps
(`vref_untrimmed_line_3sigma`, `vref_trimmed_line`, `trim`, `supply`) and
**seven** are not — six covered by passing citations and one, `psrr_dc`,
covered by a citation that fails its ratified Target. Read 0011 §5 with those
figures wherever it says nine, "eleven minus two" or "of the remaining five".
0011's text — §5 and its status line included — is left exactly as recorded.

## Alternatives considered

- **Amend 0011 §5 in place as a non-substantive count fix.** Rejected: 0011
  is `Status: ratified`, and the convention is absolute — `spec/README.md`:
  "a ratified record is superseded, never rewritten"; `TEMPLATE.md`: "Do not
  rewrite a ratified record; supersede it".
- **Let the erratum stand and correct only the two READMEs (issue #105).**
  Rejected: it leaves a ratified record permanently contradicting the
  manifest on a count a reader may quote, and the site is outside the scope
  of issue #103's planned prose-count checker (whose class is
  envelope-derived; §5's figure is manifest-derived), so nothing would guard
  it.

## Consequences

- 0011 §5 is read with eleven / four / seven in place of nine / "eleven minus
  two" / five. No other sentence of 0011 changes and its status line is
  untouched — the same treatment 0014 §3 gives 0013 ("not rewritten … and
  keeps its own status line").
- No manifest, evidence, attestation or bench artifact changes:
  `spec_rows.5`, item 5's `unmet` / `check_failed` grading and
  `failed_rows: ["psrr_dc"]` stand as recorded, and nothing under `attest/`
  pins any file under `spec/decision-records/`, so no evidence record is
  regenerated.
- The two README sites carrying the same arithmetic are issue #105's, not
  this record's; a regression checker for prose counts is issue #103's.

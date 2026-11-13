# Block manifests

`sg13cmos5l-bandgap.json` is the block manifest graded by `klt signoff`
against the T1 checklist. Its `evidence` map gains one
citation per checklist item as artifacts land (item 2: `evidence/item2.json`,
written by `attest/make-item2-envelope.py`, see `layout/README.md`; item 5: a
**list** of five `klt sim` envelopes, see below; item 9:
`evidence/item9.json`, see `attest/README.md`; item 10: `evidence/item10.json`,
produced from `attest/item10.json`).

## Item 5: five envelopes and a declared row set

Item 5 (full corner verification) is the one list-form citation here. Each
member names the `spec/target-spec.md` row ids it covers, and the manifest
declares the **full** row set under `spec_rows.5`:

| Envelope (under `sim/<bench>/envelopes/`) | Rows |
|---|---|
| `closed-loop-vref-pvt` | `vref_nominal` |
| `closed-loop-vref-pvt-boxtc` | `tc_endpoint`, `tc_box` |
| `closed-loop-psrr` | `psrr_dc` |
| `closed-loop-iq` | `iq` |
| `closed-loop-startup` | `startup_self_starting`, `startup_time` |

Coverage is **derived, not asserted**: each bench tags its graded measurements
with `measurements[].spec_row`, so `klt signoff` checks the envelope for a
passing, `limits`-bearing measurement per named row and reports
`row_coverage.row_sources` as `derived`. A row this manifest named but the
envelope did not tag would be reported `uncovered`, not believed.

Four of the nine declared rows are **gaps** — the untrimmed-line (3σ),
trimmed-line and Trim rows, and `supply` — and a fifth, `psrr_dc`, is cited by
an envelope that **fails** its ratified Target at 24 of 45 points, so item 5
grades `unmet` / `check_failed` by design (`failed_rows: ["psrr_dc"]`). The Area and Signoff rows of the spec table are
deliberately not declared under item 5: T1 items 2, 3 and 4 grade them. The
reasoning, and why a narrower row set was rejected, is in
[`0011`](../spec/decision-records/0011-corner-verification-pvt-grids.md) §5.

No `content_hash` is pinned on the item-5 citations. A `klt sim` envelope's
`provenance.input` hashes the per-corner **deck**, which `sim/grid-run.sh`
generates under `sim/build/` (gitignored), so a pinned hash would bind the
manifest to a path no reviewer and no CI run has. What pins these envelopes
instead is the record beside each one: the deck, template and request sha256s,
plus the `models_staged` hashes the fleet worker reported back.

- `design-evidence-tiers.md` is the checklist, vendored byte-identical from
  `2AMLogic/klayout-tools` `docs/design-evidence-tiers.md` at commit
  `44cc42323184` (git blob `2f7f69825f8c`).
- `sg13cmos5l-bandgap.signoff.json` is the verdict of record: the committed
  output of `klt signoff`, pinned to `klayout-tools==0.8.0` (the first release with `--attest`).

## Item 6: one `klt yield` report, a pinned sample set, and an honest `ratified: false`

Item 6 (statistical claims carry Monte Carlo evidence) cites the `klt yield` report
of `sim/closed-loop-vref-mc` and declares the full statistical row set under
`spec_rows.6`. Which rows are statistical, and why the others are not, is accounted
for row by row in
[`0012`](../spec/decision-records/0012-statistical-mc-sections-and-window.md) §4.

| Row | Declared |
|---|---|
| `vref_untrimmed_line_3sigma` | cited, **`ratified: false`** |
| `vref_trimmed_line` | **gap** — needs a trim network this design does not contain |

`ratified: false` is doing real work here. The campaign measured the row's quantity
— 2700 draws, seed recorded, a deterministic zero-spread control, a known-bad control
the statistics **detect**, a sufficient sample size — but two things about it are
unratified: the `min`/`max` the yield is computed against is an *evidence-reporting
window* quoted out of the item-5 envelope rather than a bound the spec ratifies (it
ratifies none for this row), and the device-mismatch mechanism the row names is only
partly reachable at the pin. So item 6 grades **`unmet` / `partial_coverage`**, never
`met`, and that is the intended outcome rather than a thing to fix.

**This citation pins a `content_hash`, where the item-5 ones do not.** A `klt sim`
envelope's `provenance.input` hashes a per-corner deck generated under `sim/build/`
(gitignored), so a pin there would bind the manifest to a path no reviewer has. A
`klt yield` report's freshness pin is instead the **sample-set document** its
`samples` field names — and that document is committed beside the report, carrying
both populations and the sha256 of both source envelopes, so the pin is checkable
from a clean checkout. Its one limit, which `klt yield`'s own docs state: `klt
signoff` does not recursively re-hash the campaigns that document's `derivation`
block names, so editing a source envelope without re-running `sim/mc-yield.sh` would
leave the pin satisfied. `sim/tests/test-mc-bench.sh` re-checks that both named
envelopes are committed, and envelopes are append-only.

**A grading quirk to know before reading the report.** Item 6's `detail` lists
`vref_untrimmed_line_3sigma` under `uncovered_rows` as well as `unratified_rows`,
although the citation resolves and passes its campaign-discipline gates. `klt
signoff`'s item-6 row reader counts only a citation whose report `status` is `pass`,
and a report declaring no `target_yield` is `status: "reported"` — the correct state
for a row that ratifies no yield claim. Declaring a target the campaign is known to
clear would make the row read as covered; that is manufacturing a claim to satisfy a
grader, so it is not done. Filed generically as
[`klayout-tools#5490`](https://github.com/2AMLogic/klayout-tools/issues/5490).

## Regenerating the record

Run from the repo root (the record embeds the `--tiers-doc` path). Exit 3
means "grader ran, items unmet" and is expected until T1 is reached.

```
uvx --from "klayout-tools==0.8.0" klt signoff \
    --manifest manifests/sg13cmos5l-bandgap.json \
    --tiers-doc manifests/design-evidence-tiers.md \
    --format json > manifests/sg13cmos5l-bandgap.signoff.json
```

Any change to the manifest, the checklist or cited evidence must regenerate
the record in the same PR. `.github/workflows/signoff.yml` re-runs the
command with the same pin (0.8.0), accepts exit 0 and 3 only, and byte-compares.

## Item 10 attestation

```
uvx --from "klayout-tools==0.8.0" klt signoff --attest 10 \
    --inventory attest/item10.json -o evidence/item10.json
```

Update the `content_hash` cited in the manifest if the envelope changes, then
regenerate the record. CI runs the same command with `--check`.

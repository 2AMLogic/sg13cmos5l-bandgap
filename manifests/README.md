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
trimmed-line and Trim rows, and `supply` — so item 5 grades `unmet` /
`partial_coverage` by design. The Area and Signoff rows of the spec table are
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

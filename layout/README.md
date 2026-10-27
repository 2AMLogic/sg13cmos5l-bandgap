# layout

Layout generators and committed GDS for the SG13CMOS5L cells, migrated from
`2AMLogic/sg13g2-bandgap` at `52535387e6ccf0a89f6490901a9abb2b78144176` by
[decision record 0007](../spec/decision-records/0007-migrate-sg13cmos5l-layout.md).
Files are byte-for-byte the source's, unedited; the record lists each blob.

| Path | Role |
|---|---|
| `_klayout_builder_base.py`, `common_sg13cmos5l.py` | shared drawing helpers (imported by every generator) |
| `sg13cmos5l-bandgap_{core,amp,startup}/generate.py` + `.gds` | leaf cells |
| `sg13cmos5l-bandgap_top/generate.py` + `.gds` | assembly: instantiates the three leaf GDS and draws the inter-cell routing |
| `area.json` | `klt stats` envelope of the top GDS (layout-derived area, see below) |

## Regenerate

The generators use only `klayout.db`: no PDK checkout and no files outside
`layout/` are read. Run from the repo root, leaves first (the top reads their
GDS):

```
for c in core amp startup top; do
  uv run --with klayout python3 layout/sg13cmos5l-bandgap_$c/generate.py
done
```

GDS write timestamps are disabled, so output is byte-stable: a rerun at the
source commit's generators reproduced all four committed streams
byte-for-byte (checked with `cmp`, klayout 0.30.12). Run `git diff` after.

## Evidence

T1 item 2 cites `evidence/item2.json`, bound to the top GDS
(`sha256:4e4e4f85fa08…`) with a regeneration claim. klayout-tools 0.8.0 has no
verb that emits an item-2 envelope (`klt signoff --attest` covers items 1, 9
and 10), so `attest/make-item2-envelope.py` writes it; it does not run the
generator. After regenerating, pass the fresh stream with `--regenerated`,
update the cited `content_hash` in the manifest, and regenerate the signoff
record (`manifests/README.md`).

## Assembled-top area (layout-derived, not simulated)

From `klt stats` on `sg13cmos5l-bandgap_top.gds`, top cell
`sg13cmos5l_bandgap_top` (`area.json`):

- Bounding box: 248.0 × 135.514 µm = **33 607.5 µm²** (the cell footprint; the
  Area row of `spec/target-spec.md` is "whole `bandgap_top` cell").
- Drawn area, all layers, overlaps unioned: 21 177.4 µm²
  (raw sum 21 279.96 µm²).

This gives the number only; no budget is set, and the Area row stays
`target-only`. The stream is the source's pre-spec floorplan and is not
claimed to be DRC- or LVS-clean (issues #28, #29).

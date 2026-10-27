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
`target-only`. The stream is not claimed to be LVS-clean (issue #29).

## DRC (T1 item 3)

`klt drc --deck sg13cmos5l` (`klayout-tools==0.8.0`, klayout 0.30.12, deck
content hash `sha256:5a43b8eb0e1a4c228169cd33d820bf75ca5640812587f68c07f24f4aa2a1738f`)
is `status: clean`, 0 violations, on each committed stream. Reports sit
beside their cell as `drc.json` (`amp`, `core`, `startup`, `top`); the
`top` report is the one cited by `manifests/sg13cmos5l-bandgap.json` for
item 3. Freshness: `klt drc --check layout/<cell>/drc.json`.

"Clean" is measured inside a starter-grade deck, quoted verbatim from the
`top` report's `coverage` block:

- `layers_in_stream_without_rules`: ["8/2", "28/0", "44/0", "63/0", "111/0", "128/0"]
- `rules_skipped`: ["metal1.enclosing.via1.1", "metal2.enclosing.via1.1", "metal2.enclosing.via2.1", "metal2.space.1", "metal2.width.1", "metal3.enclosing.via2.1", "metal3.enclosing.via3.1", "metal3.space.1", "metal3.width.1", "metal4.enclosing.topvia1.1", "metal4.enclosing.via3.1", "metal4.space.1", "metal4.width.1", "topmetal1.enclosing.topvia1.1", "topmetal1.space.1", "topmetal1.width.1", "topvia1.space.1", "topvia1.width.1", "via1.space.1", "via1.width.1", "via2.space.1", "via2.width.1", "via3.space.1", "via3.width.1"]
- `deck_scope`: ["5.1 NWell", "5.16 Metal1", "5.17 Metaln", "5.19 Via1", "5.20 Vian", "5.21 TopVia1", "5.22 TopMetal1", "5.5 Activ", "5.8 GatPoly", "Via1 upper-landing containment (curated)", "Via2 upper-landing containment (curated)", "Via3 upper-landing containment (curated)"]

Every rule in `rules_skipped` is reported as `inapplicable` with reason
`no_applicable_geometry` (`coverage.inapplicable`): the layout draws no
Metal2+ or via geometry, so those rules had nothing to check. Rule-free
drawn layers (`8/2`, `28/0`, `44/0`, `63/0`, `111/0`, `128/0`) are not
checked at all. This is a deck coverage limit, not a waiver.

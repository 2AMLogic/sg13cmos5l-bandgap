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

## SG13CMOS5L layer numbers

Every GDS `(layer, datatype)` pair the generators draw is defined once, as the
`L_*` constant block and `LAYER_NAMES` mapping in
[`common_sg13cmos5l.py`](common_sg13cmos5l.py), and every ERC/DRC/LVS artifact
in this repo is graded against these numbers. Each pair was read from the resolved
CMOS5L technology's own layer-properties file
(`ihp-sg13cmos5l/libs.tech/klayout/tech/sg13cmos5l.lyp`, IHP release v0.2.0
as installed at `~/share/pdk/ihp-sg13cmos5l`) — not copied from SG13G2's
table and not assumed identical to it.
The 14 entries of `LAYER_NAMES`:

| `L_*` constant | Name (`LAYER_NAMES`) | GDS layer/datatype |
|---|---|---|
| `L_ACTIV` | Activ.drawing | 1/0 |
| `L_GATPOLY` | GatPoly.drawing | 5/0 |
| `L_CONT` | Cont.drawing | 6/0 |
| `L_NSD` | nSD.drawing | 7/0 |
| `L_METAL1` | Metal1.drawing | 8/0 |
| `L_METAL1_PIN` | Metal1.pin | 8/2 |
| `L_PSD` | pSD.drawing | 14/0 |
| `L_SALBLOCK` | SalBlock.drawing | 28/0 |
| `L_NWELL` | NWell.drawing | 31/0 |
| `L_NWELL_PIN` | NWell.pin | 31/2 |
| `L_THICKGATEOX` | ThickGateOx.drawing | 44/0 |
| `L_TEXT` | TEXT.drawing | 63/0 |
| `L_EXTBLOCK` | EXTBlock.drawing | 111/0 |
| `L_POLYRES` | PolyRes.drawing | 128/0 |

`Metal1.pin` (8/2) carries net-name text only, never geometry: `klt`'s curated
`sg13cmos5l` extraction deck reads net names from it. `NWell.pin` (31/2) is the
deck's well label layer, but this layout deliberately draws nothing on it:
since the base ring's own `Cont` rows (issue #170, decision record
[0022](../spec/decision-records/0022-pnpmpa-base-tie-contacts.md)) connect each
`pnpMPA` base well, through the ring's n+ `Activ` and its Metal1, to the
base-ring net label without any well text (`common_sg13cmos5l.py:606-616`).
The #240 `nSD` marker ring that used to be cited here is gone.

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
(`sha256:7f6e35d5fa145…`) with a regeneration claim. klayout-tools 0.8.0 has no
verb that emits an item-2 envelope (`klt signoff --attest` covers items 1, 9
and 10), so `attest/make-item2-envelope.py` writes it; it does not run the
generator. After regenerating, pass the fresh stream with `--regenerated`,
update the cited `content_hash` in the manifest, and regenerate the signoff
record (`manifests/README.md`).

The current envelope is [0022](../spec/decision-records/0022-pnpmpa-base-tie-contacts.md)'s
regeneration (#170's base-tie repair: base-ring contacts added, the ten PNP
`nSD` markers removed). The committed stream is the repaired one, its rerun
verified byte-identical with `cmp`, and the item-2/item-3 hashes and the
signoff record refreshed in the same change — items 2 and 3 both remain
`met`. Superseded stream of record: `sha256:4e4e4f85fa08…` (item 2 committed
at `33249ff` / PR #41, item 3 at `fce5dca` / PR #44; both cited by 0022).

## Assembled-top area (layout-derived, not simulated)

From `klt stats` on `sg13cmos5l-bandgap_top.gds`, top cell
`sg13cmos5l_bandgap_top` (`area.json`):

- Bounding box: 248.0 × 135.514 µm = **33 607.5 µm²** (the cell footprint; the
  Area row of `spec/target-spec.md` is "whole `bandgap_top` cell"). Unchanged
  by the 0022 repair — the base-ring walls widen inward from the fixed PCell
  outer extents.
- Drawn area, all layers, overlaps unioned: 21 153.49 µm²
  (raw sum 21 252.98 µm²; down from 21 177.44 / 21 279.96 on the superseded
  stream — the ten removed `nSD` rings outweigh the widened base walls).

This gives the number only; no budget is set, and the Area row stays
`target-only`. The stream is not claimed to be LVS-clean (issue #29).

## Extraction (T1 item 7)

The `top` stream extracts, under the same pinned deck, into a
parasitic-annotated netlist with a clean `parasitic_integrity` result (13 nets,
0 findings) and fully biased device bodies — committed with its `klt pex`
envelope under [`sim/pex-bandgap-top/`](../sim/pex-bandgap-top/README.md).
[0022](../spec/decision-records/0022-pnpmpa-base-tie-contacts.md)'s
regeneration forced a fresh extract-only run on the repaired stream (the
record pins the layout hash); the delta/measurement half stays #32's.

What it does **not** yield is a post-layout figure for any spec row. The curated
`sg13cmos5l` extraction deck declares no bipolar device class, so the core's
three `pnpMPA` devices are absent from the extracted netlist (17 devices against
the design's 20 cards / 27 units; every MOS and both poly-resistor flavours match
card-for-card), and a schematic-vs-extracted delta against it would compare two
different circuits. Filed upstream as
[klayout-tools#5477](https://github.com/2AMLogic/klayout-tools/issues/5477);
decision record
[`0012`](../spec/decision-records/0012-post-layout-pex-extraction-gap.md). This
is the same deck-coverage gap the generators' own docstrings describe for LVS —
confirmed upstream as klayout-tools#4927 (closed) — reaching extraction, where
`klt lvs`'s runset-engine escape hatch has no counterpart. On the repaired
stream that escape hatch itself now derives the full `pnpMPA` inventory with
every base terminal on one shared `vss` net
([0022](../spec/decision-records/0022-pnpmpa-base-tie-contacts.md),
[measurement](../measurements/2026-11-pnpmpa-base-tie-repair/README.md)) —
0018's runset disclosure has lapsed for this stream; the curated-deck gap
0012 records has not moved.

## ERC (T1 item 11, structural half)

`klt erc` (`klayout-tools==0.8.0`, klayout 0.30.13) with
[`sg13cmos5l-bandgap_top/erc-supply-spec.json`](sg13cmos5l-bandgap_top/erc-supply-spec.json)
on the `top` stream it graded, the pre-0022
`sha256:4e4e4f85fa08…`: `erc_status: "clean"`, zero findings. The report
is committed beside the spec as `erc_report.json`
(`sg13cmos5l-bandgap_top/erc_report.json`); its freshness check
(`klt erc --check layout/sg13cmos5l-bandgap_top/erc_report.json --rerun`,
run from the repo root — the report's paths are repo-scoped) matches that
stream hash. Decision record
[`0020`](../spec/decision-records/0020-migrate-erc-supply-spec.md) migrates
the spec from the pinned source and records the runs.

**Binding after 0022** (#170's repair): the committed stream is now the
repaired `sha256:7f6e35d5fa145…`, and this production spec — #167's file,
unchanged here — keys its PNP tie on the #240 `nSD` marker the repaired
stream no longer draws, so run against the repaired stream it reports ten
"no tap contact drawn" findings. That marker-only form is the known weak
control: it passed the known-bad superseded stream precisely because a
marker without a contact grades nothing. The repaired stream's base tie is
graded by the contact-qualified population spec
(`tap_requires ["6/0"]`, wells `31/0` minus poly): ten
`erc.missing_tie` on the superseded hash as the negative control, zero
findings and both rails 1 of 1 on the repaired hash —
[0022](../spec/decision-records/0022-pnpmpa-base-tie-contacts.md) and its
[measurement](../measurements/2026-11-pnpmpa-base-tie-repair/README.md)
carry the runs. Migrating the production spec itself to the
contact-qualified form is #167's domain, not this file's change.

The spec's `ties[]` declares the three well populations separately, every
tap in boolean form (`tap_requires`, never a bare `tap_layer`):

- `nwell_tap_vdd` — the two MOS shared wells (selected by
  `well_requires: ["5/0"]`, the only `NWell` islands carrying gates), each
  tied by its #240 `nSD`-covered `Activ` tap island through `Cont` to
  `Metal1` and the `vdd` rail.
- `pnp_base_well_tap_vss` — the ten `pnpMPA` base wells (the gate-free
  complement, `well_excludes: ["5/0"]`), tied by the #240 `nSD`-marked base
  ring this declaration keys on (record
  [`0018`](../spec/decision-records/0018-pdk-runset-pnpmpa-nsd-ring.md);
  a marker the repaired stream no longer draws — see the binding note above)
  through `Cont` to the `Metal1` base ring labelled `vss`.
- `substrate_tap_vss` — the native p-substrate (`well_layer: null`,
  `well_complement_of: ["31/0"]`: top-cell extent minus the merged n-well
  union), tied by the ten `pSD`-covered collector rings outside every well
  (10 polygons, 75.74 µm²) to `vss`.

Finding attribution (issue #167's acceptance criterion): the baseline run
with the migrated spec **unedited** reproduced the source's ten
`erc.missing_tie` findings on `nwell_tap_vdd` — one per `pnpMPA` base well,
each bbox naming the device, `erc_status: "violations"`, both rails still
1 of 1 (record 0020 §Decision 2 keeps it as evidence). Each of the ten is
attributed to a **spec declaration gap** — the single `vdd`-only tie grading
wells whose correct tie is `vss` — and nothing else: not a layout defect
(no follow-up issue owed) and not a `klt erc` gap (no upstream issue owed);
splitting the declarations per population is the whole fix, and the rerun
grades all three ties in `erc_coverage.checked` with nothing `skipped`.
Zero findings is not the whole coverage story: the two `nwell_tap_vdd`
wells and ten `pnp_base_well_tap_vss` wells are graded as drawn geometry
per merged island, while `substrate_tap_vss` additionally appears in
`erc_coverage.checked_by_well_assertion` — an asserted region with no drawn
layer to corroborate it, the weaker provenance stated in the report itself.
`layers_in_stream_without_declaration` is
`["28/0", "44/0", "63/0", "111/0", "128/0"]` (resistor/pin layers outside
the ERC model; 14/0 left the list when the substrate tie declared it).

The LVS supply pairing, the item-11 manifest citation and the signoff CI
re-run are #36's half of item 11 and are untouched here.

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

# 0020: Migrate the ERC supply spec and declare its ties per well population — the ten baseline findings were a spec declaration gap

- **Status**: ratified, effective when the PR for issue #167 merges
- **Date**: 2026-11-20
- **Decided by**: Loom Builder agent, issue #167 (amends 0002 for this file only; sibling of 0006/0007)

## Context

T1 item 11 (Power delivery, structural) needs a `klt erc` supply-spec run
on the committed stream; nothing under `layout/` declared one. At the
pinned source, `2AMLogic/sg13g2-bandgap`, the spec existed
(`layout/sg13cmos5l-bandgap_top/erc-supply-spec.json`) but its single
`nwell_tap_vdd` tie graded every `NWell` island against `vdd`, so the ten
`pnpMPA` base wells — correctly tied to `vss` through their #240 `nSD`-marked
base rings — could never satisfy it: the source's klt 0.6.0 report is
`erc_status: violations`, `erc.missing_tie` ×10. Its comment block named the
two upstream capabilities a fix needed, klayout-tools#2354 (per-class well
selection) and #2255 (native-substrate tie); both are closed at
klayout-tools 0.8.0, this repo's pin.

## Decision

1. **Migrate the spec** from `2AMLogic/sg13g2-bandgap` at
   `52535387e6ccf0a89f6490901a9abb2b78144176`, byte for byte, then edit only
   `ties[]` and the comment block. `reuse.lock.json` carries the `migrate`
   entry. Blob identity, checked with `git hash-object` against the source
   tree at that commit:

   | Path | blob SHA-1 (first 12) | SHA-256 (first 12) |
   |---|---|---|
   | `layout/sg13cmos5l-bandgap_top/erc-supply-spec.json` | `2888bc22797f` | `d01f01b8b875` |

   The source's klt 0.6.0 `erc_report.json` is **not** migrated: it was run
   on a different stream (post-grid-fix `sha256:1b07a94d…`), so it is not
   evidence here (the same reasoning 0007 applied to the source's other
   reports).

2. **Baseline, unedited spec, klt 0.8.0** (KLayout 0.30.13) on the committed
   `sg13cmos5l-bandgap_top.gds`
   (`sha256:4e4e4f85fa0875651c294c95a1f65792fa1913dd20d027fbe6905f2d001cb330`,
   spec `sha256:d01f01b8b875…`): exit `3`, `erc_status: "violations"`,
   exactly ten `erc.missing_tie` findings on `nwell_tap_vdd` — one per
   `pnpMPA` base well, each finding's bbox naming the device. `vdd` and `vss`
   each matched 1 of 1 expected islands. This reproduces the source verdict
   at this repo's pin and is kept as evidence, not re-run away.

3. **Split `ties[]` per well population.** Every `NWell` (31/0) island on the
   committed GDS was probed and falls in exactly one of three counted
   populations: two MOS shared wells — the only islands interacting with
   GatPoly (5/0), each holding exactly one `nSD`-covered `Activ` tap island
   (#240 `draw_well_tap`) wired to `vdd`; ten `pnpMPA` base wells — the
   gate-free islands, each tying to `vss` through its #240 `nSD`-marked base
   ring (which record 0018 keeps); and the native p-substrate — no drawn
   well/tub layer anywhere on the stream, tied to `vss` through the ten
   `pSD`-covered collector rings (10 polygons, 75.74 µm² total). The
   declarations:

   - `nwell_tap_vdd`: `well_layer: "31/0"`, `well_requires: ["5/0"]`,
     `tap_layer: "1/0"`, `tap_requires: ["7/0"]` → `Metal1` → `vdd`
   - `pnp_base_well_tap_vss`: `well_layer: "31/0"`,
     `well_excludes: ["5/0"]` (the complement of the first selector, so both
     entries together grade every n-well exactly once), same tap shape → `vss`
   - `substrate_tap_vss`: `well_layer: null`, `well_complement_of: ["31/0"]`
     (the graded region is the top-cell extent minus the merged n-well union,
     derived from the stream), `tap_requires: ["14/0"]` → `vss`

   Every tap keeps the boolean-implant form (`tap_requires`); no bare
   `tap_layer`. The GatPoly selector is the gate-bearing/gate-free
   distinction between a CMOS-territory well and a bipolar base tub — the
   complementary-pair shape `docs/cli/erc.md` at v0.8.0 documents as the
   canonical two-bias-class case — and stays falsifiable: a poly riser
   routed across a `pnpMPA` well in a future revision would move that well
   into the `vdd` class and fail it.

4. **Commit the final report** as
   `layout/sg13cmos5l-bandgap_top/erc_report.json` (klt 0.8.0, KLayout
   0.30.13, both hashes in `provenance`): `erc_status: "clean"` — zero ERC
   findings, no `erc.unconnected_net`, no `erc.supply_short`, `vdd`/`vss`
   each 1 of 1 expected islands. All three ties appear in
   `erc_coverage.checked` with nothing `skipped`; `substrate_tap_vss`
   additionally appears in `erc_coverage.checked_by_well_assertion` — the
   weaker provenance a region with no drawn layer always carries, stated in
   the verdict of record rather than hidden. The report replays:
   `klt erc --check … --rerun` → `status: "match"`, empty drift.

   **The ten baseline findings are thereby attributed: a spec declaration
   gap, not a layout defect and not a `klt erc` gap.** No layout follow-up
   and no upstream issue is owed for them; per-finding attribution sits in
   `layout/README.md` §ERC.

## Alternatives considered

- **Keep the single `vdd` tie and disclose the rest.** Rejected: a
  disclosure downgrades checked work to a considered omission when all three
  classes are expressible at the pin; item 11's tie half would stay
  unmet on evidence that exists.
- **`well_boxes` for the substrate tie.** Rejected: a hand-written box list
  goes stale when the layout changes; `well_complement_of` derives the same
  region from the stream (klayout-tools#3750) with the same falsifiability
  guard.
- **Box-form class selection (`well_requires_boxes`).** Not needed: the
  stream draws a layer (GatPoly) that separates the classes, so the
  marker form grades the selection as drawn geometry rather than caller
  assertion.
- **Suppress the baseline by editing `ties[]` before the first run.**
  Rejected: the unedited-spec baseline is what proves the residual findings
  were a declaration gap; both runs are evidence.

## Consequences

- The ERC half of T1 item 11 has committed, replayable evidence with zero
  unexplained findings. The LVS supply pairing, the item-11 manifest
  citation and any signoff CI re-run stay with #36 (blocked on the item-4
  chain); a comment there records the split.
- The spec's comment block no longer cites klayout-tools#2354/#2255 as open;
  it cites them as the shipped capabilities the split uses, and its label
  counts are re-derived for this stream (80 Metal1.pin labels: 10 `vdd`
  including the two #240 tap tags, 27 `vss`).
- The substrate tie's `checked_by_well_assertion` provenance is the weakest
  link in the report; any future citation of item 11 that needs a
  drawn-well-grade substrate tie must say so (the report already does).
- Nothing about the GDS, the generators, `design/`, any ratified record or
  any spec row changes; 0007's "stays pinned" list for the source's
  per-cell reports is unaffected — this record migrates the spec only.

# closed-loop-vref-pvt-boxtc

The **Temp coefficient** row of `spec/target-spec.md` (issue #30, Part of #5): closed-loop
`vref` over −40…125 °C, **endpoint method and box method both reported**, at all 5 process
corners × 3 supplies. Every figure is **simulated**.

| File | Role |
|---|---|
| `bench.json` | Grid metadata `sim/grid-run.sh` reads: the graded criteria, the spec row ids, the OSDI objects |
| `deck.cir.tmpl` | Deck body: the same fixture as `closed-loop-vref-pvt/vref.cir.tmpl`, with no transient |
| `request-grid.json` | The committed, host-portable `klt sim` request: 15 units, each a 166-point DC sweep of `TEMP` |
| `records/`, `envelopes/` | Append-only evidence (see `sim/README.md` §PVT grids) |

```bash
source sim/env.sh && sim/grid-run.sh closed-loop-vref-pvt-boxtc
```

## Why the temperature is the analysis, not a corner axis

A temperature coefficient is a reduction **across** temperature. `klt sim` has no cross-corner
reduction — each expanded point is independent — so a `corners.temperature_c` axis cannot
express a ppm/°C figure at all; it can only report one `vref` per point and leave the division
to a post-hoc script, which would put the row's actual number outside the cited envelope.

So the sweep moves inside the unit: `analysis.kind: "dc"` with `args: "temp -40 125 1"` solves
the whole characteristic in one corner unit, and the endpoint and box reductions are ordinary
`klt sim` `expr` measurements over the swept `v(vref)` vector, graded by `limits` like any
other. The grid is therefore 5 process × 3 supply = **15 units**, each covering 166
temperatures. The row's own requirement of "8 or more temperature points" is graded, not
asserted: `temp_points` is `length(v(vref))` with `limits: {min: 8}`.

One consequence to read correctly: because temperature is not an axis, each unit's `corner_id`
reads `<process>/<supply>/27C` — `klt sim`'s default `.temp` card, which the `dc temp` sweep
overrides. **A unit covers the whole −40…125 °C range, not 27 °C.**

## Why a DC analysis is licensed here

`closed-loop-vref-pvt` needs a 2 ms transient because its settle criterion is defined on one.
A bandgap's DC operating point is the classic place to land on the degenerate (zero-current)
solution instead of the intended one, so a DC analysis is not free. It was checked before being
used, at this PDK pin:

| Where | Analysis | `vref` |
|---|---|---|
| `closed-loop-vref-pvt`, typ/3.30 V/27 °C | 2 ms transient, settled | 1.19696 V (decision record 0009) |
| this bench, typ/3.30 V, sweep index 67 | `dc temp` | 1.196961 V |

The DC solve lands on the same closed-loop operating point, to six digits. That continuity is
re-checked on every run rather than taken on trust: `vref_m40_v`, `vref_27_v`, `vref_125_v`,
`vref_min_v` and `vref_max_v` each carry a `plausible_range` of [0.5 V, 2.0 V], so a degenerate
solve is failed instead of being recorded as a characteristic.

## The two methods, written out

`dc temp -40 125 1` yields 166 points, index *i* at temperature −40 + *i* °C, so index 0 is
−40 °C, index 67 is 27 °C and index 165 is 125 °C. Both methods divide by the 165 °C span:

- **box**: `1e6 × (max(vref) − min(vref)) / (165 × (max(vref) + min(vref))/2)` — normalised at
  the box midpoint, over all 166 points.
- **endpoint**: `1e6 × |vref(125 °C) − vref(−40 °C)| / (165 × vref(27 °C))` — normalised at
  27 °C, the two endpoints only.

The `pnpMPA` base-current error term (`bf ≈ 1.10`), which the spec row names as a line item, is
inside both numbers: it is part of the DUT and is not corrected for anywhere.

## Result (SIMULATED, batch fleet, 2026-11-13)

Envelope `envelopes/20261113T115709Z-0be5a53.json`, record
`records/20261113T115709Z-0be5a53.json`, job `klt-sim-8da2d44d701e`, ngspice-47,
PDK `f7bca32…` (model text staged and hash-matched; see `sim/README.md`).

**15/15 units pass.** Graded against the ratified **Target** bound of < 50 ppm/°C (decision
record 0011 §2). The earlier envelope `envelopes/20261113T111153Z-3830083.json` is the same
grid graded against the Fallback; it is kept as append-only evidence and is no longer cited.

| Measurement | Worst case | Binding corner | Best case |
|---|---|---|---|
| `tc_box_ppm_per_c` | **39.186 ppm/°C** | `bcs/3.630V/27C` | 29.140 ppm/°C (`wcs/2.970V`) |
| `tc_endpoint_ppm_per_c` | **38.758 ppm/°C** | `bcs/3.630V/27C` | 27.998 ppm/°C (`wcs/2.970V`) |
| `temp_points` | 166 | every unit | 166 |

`vref` over the whole 15 × 166 set spans **1.188738 V … 1.200459 V**.

Against the row's other two columns, reported and **not** graded (`bench.json` says why):

| Column | Bound | Worst measured | Verdict |
|---|---|---|---|
| Fallback | < 100 ppm/°C | 39.186 | met (reported, not graded) |
| Target | < 50 ppm/°C | 39.186 | **met** (graded) |
| Stretch | < 20 ppm/°C | 39.186 | not met |

This is evidence against the row, not a new ratified number: the ratified bounds are unchanged
and nothing here is copied into the spec table's Target column.

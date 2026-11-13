# 0010: Corner verification — the five PVT-grid benches, and what they measured

- **Status**: ratified, effective when the PR for issue #30 merges
- **Date**: 2026-11-13
- **Decided by**: Loom Builder agent, issue #30

## Context

T1 item 5 (*Full corner verification vs a ratified spec*) asks, in the Analog
column, for PVT corner-matrix results covering **every** spec row at its bound
corners, with per-row pass/fail and the binding corner recorded, citing one or
more `klt sim` envelopes and declaring the full row set.

Before this change, `manifests/sg13cmos5l-bandgap.signoff.json` graded item 5
`unmet` / `no_evidence`. Of `target-spec.md`'s eleven rows, one was
`measured, single corner` ([`0009`](0009-output-reference-nominal-first-measured.md)),
one was `partial` and the rest `target-only`; three of the five planned benches
(`-pvt-boxtc`, `closed-loop-psrr`, `closed-loop-iq`) did not exist, and
`closed-loop-vref-pvt`'s 45-point request was committed but un-run, because
`klt sim`'s batch backends had refused `ihp-sg13cmos5l` (klayout-tools#2727)
and a local grid is forbidden on a dispatch host.

Two of those blockers resolved. **klayout-tools#2727 landed**: the batch image
publishes `sg13cmos5l`, so `--backend batch` accepts the variant.
**klayout-tools#3134 was closed as not planned**: the `remote` backend still has
no CMOS5L image, so `batch` is the only off-host route.

## Decision

### 1. Five benches carry item 5, one per row family

| Bench | Rows | Grid |
|---|---|---|
| `sim/closed-loop-vref-pvt` | `vref_nominal` | 45 points |
| `sim/closed-loop-vref-pvt-boxtc` | `tc_endpoint`, `tc_box` | 15 units × 166 temperatures |
| `sim/closed-loop-psrr` | `psrr_dc` | 45 points |
| `sim/closed-loop-iq` | `iq` | 45 points |
| `sim/closed-loop-startup` | `startup_self_starting`, `startup_time` | 45 points |

Each commits a host-portable `klt sim` request, tags its graded measurements
with `measurements[].spec_row`, and writes an append-only raw envelope under
`envelopes/` beside its record. The manifest cites the five envelopes and
declares the full row set under `spec_rows.5`, so `klt signoff` **derives** row
coverage from the envelopes (`row_coverage.row_sources` reads `derived` for all
seven covered rows) rather than taking the manifest's word.

### 2. The graded bound is the ratified **Fallback** column, not the Target

[`0001`](0001-target-spec-ratification.md) §5 makes the fallback the threshold
a miss is judged against ("considered only if the TC fallback (< 100 ppm/°C) is
itself missed on measured evidence"). So `limits` in each request are the
Fallback bound; the Target and Stretch are reported against the measured worst
case in each bench README and in `target-spec.md`'s Status column, and are not
graded. A Target miss on a met Fallback must not render a whole grid "failing"
and so bury the result it is reporting.

**One exception, stated in the bench:** the Startup row's Fallback column
carries no time at all, so `t_settle_s` is graded against the row's **Target**
(< 1 ms). Grading only the fallback there would leave `< 1 ms` unexpressed.

Two rows have no ratified number to grade at all. `vref_nominal`'s target is
"nominal at the TC-null point" — a method — so the bound graded at all 45 points
is this bench's own settle criterion from [`0009`](0009-output-reference-nominal-first-measured.md).
`supply` is recorded as met by construction, so it is declared a gap (§5).

### 3. The Temp-coefficient bench sweeps temperature *inside* the unit

A temperature coefficient is a reduction **across** temperature, and `klt sim`
has no cross-corner reduction: a `corners.temperature_c` axis can only report
one `vref` per point, leaving the row's actual number outside the cited
envelope. `closed-loop-vref-pvt-boxtc` therefore runs
`analysis.kind: "dc"`, `args: "temp -40 125 1"` — 166 temperatures solved in one
corner unit — over 5 × 3 = 15 units, and both reductions are ordinary graded
`expr` measurements. The row's "8 or more temperature points" is itself graded
(`temp_points`, `limits.min: 8`), not asserted.

A DC analysis on a bandgap can land on the degenerate solution, so this was
checked before being relied on: at typ/3.30 V the sweep's 27 °C point reads
`vref` = 1.196960 V against the transient bench's settled 1.19696 V. Every
`vref` measurement in that bench carries a `plausible_range`, so a degenerate
solve fails instead of being recorded as a characteristic.

### 4. A new in-repo startup bench supersedes the planned inherited one

`target-spec.md` planned the Startup row on the inherited
`sim/sg13cmos5l-closed-loop-startup` at the `reuse.lock.json` pin. That bench
recorded 45/45 points self-starting but **never extracted a settling time** —
all of its measurements are `.meas ... find ... at=` cards at 20 µs or at the
2 ms end point — which is why the row's `< 1 ms` had no evidence anywhere and
the row stood at `partial`.

`sim/closed-loop-startup` supersedes it **for this row only**. It carries the
source fixture over unchanged (200 µs `vdd` ramp, 2 ms window, `rshunt`/`gmin`)
and the source's three self-starting criteria verbatim; it adds `t_settle_s`.
The inherited bench and its `-pex` sibling remain the source of the original
self-starting record and of the only post-layout startup evidence, and the pin
is unchanged. Two deliberate differences, both in the bench README: the DUT is
the migrated hierarchical netlist ([`0006`](0006-migrate-sg13cmos5l-design-sources.md))
rather than inlined devices, so the source's `Vmkfb` ammeter is replaced by the
startup cell's own detect node `v(xx3.det)`; and one request carries the whole
supply axis via `corners.supply_waveforms` instead of one request per supply.

### 5. The declared row set is the spec's electrical rows, gaps included

`spec_rows.5` declares eleven minus two: the Area and Signoff rows are **not**
declared, because their binding conditions are a layout cell and the
DRC/LVS/ERC decks, which T1 items 2, 3 and 4 grade. Of the nine declared, seven
are covered and four are gaps — `vref_untrimmed_line_3sigma` (a device-mismatch
Monte Carlo reduction a corner matrix cannot express; issue #31, and T1 item 6's
claim), `vref_trimmed_line` and `trim` (no trim network exists), and `supply`
(met by construction).

**Item 5 therefore grades `unmet` / `partial_coverage`, and that is the intended
outcome.** Declaring a narrower row set would have rendered it `met` by leaving
the block's unevidenced accuracy rows out of the declaration — the relaxation
`CLAUDE.md` forbids. `uncovered_rows` and `failed_rows` are both empty: every
declared row is either covered by a passing derived citation or a named gap.

### 6. `schema_version: 1` for the grid record, and one runner for five benches

[`0008`](0008-shared-sim-runner-helpers.md) deferred a common record shape to
the first #30 bench. That shape is now the grid record: `schema_version: 1`,
carrying the PDK and source pins, the DUT/deck/template/request hashes, the
`models_staged` binding, the name of the envelope beside it, and a `grid`
reduction of the envelope's own per-row verdicts. A record with **no**
`schema_version` is one of the two legacy single-corner shapes, unchanged.

0008 also rejected "one mega-runner parameterised by bench", on the grounds that
the benches would differ in deck assembly and corner bundle. **That premise did
not hold**, and this record supersedes that part of 0008: the portable request
shape (§7) removed generated corner bundles entirely, so the five benches differ
only in a deck template, a request file and a criteria string — all three data
in the bench directory. `sim/grid-run.sh` is the single runner;
`bench.json` carries the per-bench data, including the deck and request
*filenames*, so `closed-loop-vref-pvt` keeps the names 0009 already cites.
`closed-loop-vref-pvt/run.sh` stays as the single-corner local probe.

### 7. Requests are host-portable, and the models are bound to the pin by hash

Every committed request names `models.pdk: "ihp-sg13cmos5l"` plus PDK-relative
per-section corner libraries — the §PVT mapping written out, one `{lib, section}`
per device family per corner — so no generated corner bundle and no absolute host
path exists to be refused off-host (`models_lib_host_path`). OSDI entries are
literal `$PDK_ROOT/...`, which the runner resolves on its own box and a local run
expands from the environment. One request therefore serves a local probe and the
fleet grid, which is what keeps `run.sh` from drifting from the grid it narrows.

`options.stage_model_inputs: true` is **load-bearing, not cosmetic**: the batch
image's SG13CMOS5L tree publishes no readable revision stamp
(`worker_environment.pdk.stamp_text: null`, `pdk_stamp_comparison:
not_comparable`), so a fleet-resolved grid cannot be bound to a pinned revision
at all. Staging uploads this host's pinned libraries and their whole closure (15
files) and the worker reports back the hashes it received; both lists match in
every committed envelope. **Residual gap, recorded rather than closed:** the
OSDI compact-model binaries are the image's, unstaged and unhashed. Its size is
bounded by measurement, reproducibly: `CM5_GRID_NO_STAGE=1 sim/grid-run.sh
closed-loop-vref-pvt` reruns the grid against the image's own PDK tree and
suffixes its artifacts `.image-models`, and `closed-loop-vref-pvt/envelopes/`
holds both runs — all 315 measurements agree exactly. Filed as generic tool
friction at `2AMLogic/klayout-tools#5457` (a request with per-section corner
libraries has no `models.lib`, so no batch report can attest the models the
runner executed; the unreadable image stamp is #5321/#5318).

### 8. `netlist_source` correction

`closed-loop-vref-pvt/request-45pt.json` read `netlist_source: "extracted"`. The
DUT is the xschem export migrated by [`0006`](0006-migrate-sg13cmos5l-design-sources.md),
not a netlist extracted from layout, and `klt sim` takes the field as the
caller's word. It now reads `"schematic"` in every request. Committed records are
append-only and are not edited.

## Alternatives considered

- **Grade the Target column.** Rejected: on measured evidence PSRR's Target is
  missed, so every PSRR envelope would read `fail` and item 5 would report
  `check_failed`, hiding a met Fallback behind a failed check. 0001 §5 makes the
  fallback the decision threshold. The miss is instead recorded explicitly, here
  and in the spec's Status column.
- **Relax or restate the PSRR target.** Rejected outright: agents do not relax
  the ratified spec to make results pass (`CLAUDE.md`). The bound is unchanged.
- **Declare only the covered rows under `spec_rows.5`.** Rejected: it would
  render item 5 `met` while the untrimmed-line, trimmed-line and trim rows have
  no evidence at all. The tier text asks for the *full* row set.
- **PSRR by `ac` analysis at a low frequency.** Rejected: the row says DC only
  and explains why (a frequency point depends on capacitor values the MoM models
  carry no spread for), and a 1 Hz `ac` sweep is still a small-signal frequency
  point. Two DC operating points and a 0.1 V secant are used instead, with
  tightened solver tolerances so the 100 µV difference is not Newton residual.
- **A temperature corner axis plus a post-hoc ppm/°C script.** Rejected: the
  row's actual number would then live outside the cited envelope, so item 5
  could only ever assert that row, never derive it.
- **Insert the source bench's `Vmkfb` ammeter into the DUT.** Rejected: it
  requires editing the migrated netlist, which 0006 forbids.
- **Stage the OSDI binaries too.** Rejected for now: it needs a host-absolute
  `osdi_preload` path, which would make every request unportable and
  non-committable. The gap is disclosed and bounded by measurement instead.
- **Split this into one PR per bench.** Rejected: the row set is declared once,
  in one manifest, and a partial declaration grades item 5 against a row set
  that does not describe the spec.

## Consequences

- `klt signoff` grades item 5 `unmet` / `partial_coverage` with five `met`
  citations, seven `derived` covered rows, no uncovered or failed rows, and four
  named gaps. T1 stands at 4/11 met; item 5 moves from `no_evidence` to a stated
  partial. The committed `manifests/sg13cmos5l-bandgap.signoff.json` is
  regenerated in the same change and `--check` reports `match`.
- Seven rows of `target-spec.md` move to `measured, PVT grid`, a status value
  this record adds. Each carries its worst case and binding corner.
- **The PSRR @ DC Target is missed**: 55.249 dB worst case at `wcs`/2.97 V/125 °C
  against a > 60 dB Target (> 50 dB Fallback met at all 45 points). The worst
  corner is where the amplifier's loop gain is lowest, and this block carries the
  source amplifier unchanged (0006), so closing the gap is an amplifier change —
  a design decision outside this issue, not a spec change.
- Item 5 cannot become `met` until the mismatch Monte Carlo row has evidence
  (issue #31) and the trim rows have a trim network. Those are the gaps the
  report now names.
- `attest/item9.json` gains the four new benches' deck templates and requests;
  `evidence/item9.json` and the manifest's item-9 hash are regenerated with them.
- Every figure in this record is **simulated**, on the batch fleet, ngspice-47,
  PDK `f7bca32694fe3d58be0cc7d9df4b9f5db7161a14`, with the model text staged from
  that pin and hash-matched by the worker. No silicon claim is made.

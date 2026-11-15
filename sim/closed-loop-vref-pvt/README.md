# closed-loop-vref-pvt

First closed-loop `vref` bench (issue #14, part of #5). It is the planned bench behind the
"Output reference, nominal" row of `spec/target-spec.md`. Every figure is **simulated**.

| File | Role |
|---|---|
| `run.sh` | Single-corner probe: one `klt sim --backend local` unit at typ / 27 °C / 3.30 V, writes one record |
| `vref.cir.tmpl` | Deck template: supply, substrate tie, include of the in-repo DUT netlist |
| `request-45pt.json` | The full §PVT grid (5 process × 3 temperature × 3 supply = 45), **run** — see "The 45-point grid" below |
| `bench.json` | Grid metadata `sim/grid-run.sh` reads: the graded criteria, the spec row id, the OSDI objects |
| `records/` | Append-only JSON records (`<UTC>-<short sha>.json`), from both runners |
| `envelopes/` | Append-only raw `klt sim` envelopes from the grid runner; **what `manifests/` cites for T1 item 5** |

Two runners share this directory on purpose: `run.sh` is the local single-corner probe decision
record 0009 cites, and `sim/grid-run.sh closed-loop-vref-pvt` is the 45-point grid (issue #30).
Both read the same `request-45pt.json` and the same `vref.cir.tmpl`, so the probe cannot drift
from the grid's models, analysis or measurements.

## Run

```bash
source sim/env.sh && sim/closed-loop-vref-pvt/run.sh                 # one local corner
source sim/env.sh && sim/grid-run.sh closed-loop-vref-pvt            # the 45-point grid, batch fleet
```

Prerequisites are those of the smoke bench (`sim/README.md` 'Cold start'), plus both `psp103.osdi` and `r3_cmc.osdi` built (`rppd`/`rhigh`
need `r3_cmc`). Exit codes: 0 record with `vref_v`; 3 missing prerequisite; 4 record exists;
5 simulation failed (a record with `status: failed` and `failure_reason` is written); 6 source
netlist missing or pin unreadable (named `SOURCE_MISSING`, no record).

## Where the DUT comes from

`design/sg13cmos5l/netlist/bandgap_top.spice` is the in-repo copy migrated byte-for-byte from
`2AMLogic/sg13g2-bandgap` at the commit in `reuse.lock.json` (decision record 0006, which amends
0002 for these cells); the runner reads it, no forge access. The file is a flattened xschem export
whose top block is **commented out**: `**.subckt bandgap_top vdd vss vref`, the bare instances
`Xx1`/`Xx2`/`Xx3` on nets `vdd vss vref fb sns1 sns2`, `**.ends`, then the `bandgap_core`,
`bandgap_amp`, `bandgap_startup` subckts, no `.lib`/`.include`. The deck therefore drives
`vdd`/`vss`, declares `sub!` global and ties that bulk net to `vss`, and supplies the model
`.lib`s. The `.global sub!` card is what makes the tie reach the leaf resistors' bulk
terminals: `!` is an xschem marker, not an ngspice one, so without it `Vsub sub! vss dc 0`
drives a top-level node while the `rppd`/`rhigh` bulks sit on per-instance local nodes held
only by `.options rshunt` (issue #83, decision record 0014).

Staging (`cm5_stage_dut`) makes exactly three derived changes and never edits the source:
the commented top header becomes a live `.subckt sg13cmos5l_bandgap_top vdd vref vss`, its
`**.ends` becomes `.ends sg13cmos5l_bandgap_top`, and the final `.end` card is dropped. The
deck instantiates the result as `Xdut vdd vref vss sg13cmos5l_bandgap_top`, so internal nodes
are addressed as `v(xdut.fb)` / `v(xdut.sns1)` / `v(xdut.sns2)`. That cell name and pin order
are the layout-extracted netlist's, which is what lets one deck serve both legs of the T1
item-7 delta; it is electrically a no-op, and decision record 0013 records the measurement
showing it. `source_file_sha256` in each record is still the hash of the file **as read**
(equal to the pinned source blob); `staged_dut_sha256` is the hash of the wrapped copy.

## Record

Fields: `pdk_revision` (equals `sim/pdk.json` `revision`, enforced by `sim/env.sh`),
`source_commit`, `deck_sha256`, `corner`, `vref_v`, plus `label: SIMULATED`, `testbench`,
`settle_criterion`, simulator versions and the `klt` envelope. `vref_v` is read at 2.0 ms of a
2 ms transient from DC sources; it is accepted only if `|vref(2.0 ms) − vref(1.5 ms)| < 1 mV`.

## Non-convergence is a finding

If the DUT netlist does not converge or settle at the `dev` pin, the runner writes a record
with `status: failed`, no `vref_v` and the reason, and exits 5. The source netlist is not edited.
`cornerRES.lib res_typ` is the §PVT-table name and is not exercised by the smoke bench; if it does
not resolve at this pin the failure is recorded here and cross-referenced to #15.

`run.sh` narrows the request to one corner (typ/27 C/3.30 V) and also lowers `timeout_s` from 600 to 300.

## The 45-point grid

It has run (issue #30). `klayout-tools#2727` landed — the batch fleet's image publishes
`sg13cmos5l`, so `--backend batch` accepts `ihp-sg13cmos5l`; `#3134` was closed as not planned,
so the `remote` backend still has no image and **batch is the only off-host route**. Host rules
forbid a local grid either way (`sim/README.md` §PVT grids).

Three things in the request had to change before it could leave this host, all of them in the
direction of portability rather than of a different measurement:

- The absolute `netlist`/`models.lib` paths and the generated `corners.lib` bundle are gone.
  The request now names `models.pdk: "ihp-sg13cmos5l"` plus **PDK-relative per-section corner
  libraries**, one `{lib, section}` per device family per corner — the §PVT table's mapping,
  written out. `batch` refuses an absolute host path in `models.lib` (`models_lib_host_path`),
  and a bundle file generated under `sim/build/` is not a file the runner has.
- `options.osdi_preload` entries are written as literal
  `$PDK_ROOT/ihp-sg13cmos5l/libs.tech/ngspice/osdi/...`, which `klt sim` forwards unexpanded for
  the runner to resolve, and expands from the environment on a local run. One request therefore
  serves both.
- `options.stage_model_inputs: true` ships this host's pinned model libraries with the job. See
  `sim/README.md` → "What the fleet runner cannot prove (and what staging fixes)" for why that
  is load-bearing and what residual gap it leaves.

`run.sh` narrows the same file to the `typ` bundle at 27 °C / 3.30 V and lowers `timeout_s`;
it no longer overrides the models or the OSDI entries at all.

### The `netlist_source` correction

`request-45pt.json` declared `netlist_source: "extracted"` before issue #30. That was a
provenance mislabel: the DUT is the xschem-exported netlist migrated by decision record 0006,
not a netlist extracted from layout, and `klt sim` takes the field as the caller's word (it
never infers provenance from the file). Left alone, every item-5 envelope cited from here would
have claimed post-layout provenance for a pre-layout result — the exact distinction the field
exists to carry. It now reads `"schematic"`. The already-committed records are not edited;
they are append-only, and each carries the `template_sha256`/`deck_sha256` of what it ran.

### Result (SIMULATED, batch fleet, 2026-11-13)

**45/45 points pass**, graded on the settle criterion decision record 0009 ratified for this
bench, now applied to every point: `vref_settle_v`, the largest `|vref(t) − vref(2 ms)|` over
t ∈ (1.5 ms, 2 ms], **< 1 mV**. Worst case **1.03e-8 V** at `wcs/3.630V/-40C`.

`vref` over the grid spans **1.18874 V** (`wcs/2.970V/125C`) **… 1.20039 V**
(`bcs/3.630V/-40C`), a ±0.49 % band about its midpoint. That span is **evidence, not a ratified
line**: the ratified untrimmed line is a 3σ mismatch figure, which needs the Monte
Carlo of issue #31 and is T1 item 6's claim, not this grid's.

No numeric accuracy bound is graded here, because the row's ratified target is "nominal at the
TC-null point" — a method, not a number — and inventing one would be ratifying a number
(CLAUDE.md). What guards the figures instead is a `plausible_range` of [0.5 V, 2.0 V] on
`vref_v`, which fails a converged-but-degenerate solution rather than recording it as a
reference.

Two envelopes from that session are committed, and the pair is itself the measurement that
bounds the fleet-image provenance gap:

| Envelope | Models | Job | Result |
|---|---|---|---|
| `envelopes/20261113T112115Z-3830083.image-models.json` | resolved on the runner from the fleet image | `klt-sim-eb3c80bdefd3` | 45/45 pass |
| `envelopes/20261113T111044Z-3830083.json` | **staged from this host's pin** (15 files, hashes matched by the worker) | `klt-sim-fbbab809f5c5` | 45/45 pass |

All **315** measurements (45 points × 7) agree exactly between the two. `manifests/` cites the
staged one, because only that envelope binds the models to `sim/pdk.json`'s revision by hash.
The cross-check is reproducible: `CM5_GRID_NO_STAGE=1 sim/grid-run.sh closed-loop-vref-pvt`
turns staging off and suffixes its artifacts `.image-models`.

## First run (issue #19)

Run on a fleet host whose `~/share/pdk` carries the pinned PDK through the fleet PDK store
(`.pdk-store.json` version `f7bca32…`), ngspice-47, all six OSDI objects built:

**`vref` = 1.19696 V, SIMULATED, typ / 27 °C / 3.30 V, closed loop**, settled
(`|vref(2.0 ms) − vref(1.5 ms)|` = 0 V < 1 mV). Record
`records/20261113T100202Z-4bfcd8b.json`; the figure moved the "Output reference, nominal" row of
`spec/target-spec.md` off `target-only` (decision record 0009). It is the 27 °C/3.30 V typ point,
**not** the TC-null nominal.

`records/` is append-only and holds three records from that session (issue #19):

| Record | Status | What it shows |
|---|---|---|
| `20261113T095937Z-4bfcd8b.json` | `failed` | The pre-fix run. `klt sim` `.include`s this bench's deck into a top deck of its own, so the deck's former SPICE title line was parsed as an `S`-prefix switch instance with no model: `ngspice_fatal` "Unable to find definition of model", `analysis_started: false`. Its `template_sha256` is the pre-fix template. Fixed in the same change (0009) by removing the title line. |
| `20261113T100202Z-4bfcd8b.json` | `ok` | First measured `vref`, the figure cited in the spec row. |
| `20261113T100302Z-4bfcd8b.json` | `ok` | A re-run, same `vref` to all recorded digits: the measurement is reproducible, and the prior records were byte-identical afterwards. |

**A second run appends, it does not exit 4.** `cm5_record_path`'s append-only guard keys on
`<UTC second>-<short sha>.json`, so exit 4 only fires on a same-second, same-commit collision;
any later run writes a new record and exits 0 (or 5). Existing records are never overwritten.

Still un-run: the mismatch Monte Carlo (issue #31). The 45-point grid has since run — see
"The 45-point grid" above; `records/` also holds the single-corner probe
`20261113T104408Z-3830083.json`, the first run of the re-shaped request, which reproduces
`vref` = 1.19696 V to all recorded digits and so shows the portability changes did not move the
measurement. Observed but not acted on here:
ngspice warns `Unknown model type pspnqs103va - ignored` for the `*_psp_rf` model variants the
PDK's `sg13g2_moshv_mod.lib` defines, because this bench preloads `psp103.osdi` and `r3_cmc.osdi`
but not `psp103_nqs.osdi`. No device in the DUT instantiates an RF variant, so the warnings are
inert; a bench that needs one must add that preload.

# closed-loop-vref-mc — the untrimmed-line statistical Monte Carlo bench

The bench behind `spec/target-spec.md`'s **Output reference, untrimmed line (3σ)**
row (`vref_untrimmed_line_3sigma`) and the evidence T1 **item 6** — "statistical
claims carry Monte Carlo evidence" — is graded on. Issue #31; the decision this
bench was asked to make, and what it may and may not be read as, are recorded in
[`0014`](../../spec/decision-records/0014-statistical-mc-sections-and-window.md).

Everything here is **SIMULATED**.

```bash
source sim/env.sh
sim/mc-run.sh zero          # the deterministic control, first: it proves the harness
sim/mc-run.sh line          # the population the row is about
sim/mc-run.sh inflated      # the known-bad variant the yield report grades as its control
sim/mc-run.sh families      # which device family carries the spread
sim/mc-yield.sh sim/closed-loop-vref-mc/envelopes/<utc>-<sha>.line.json \
                sim/closed-loop-vref-mc/envelopes/<utc>-<sha>.inflated.json
```

`CM5_MC_DRY_RUN=1 sim/mc-run.sh <campaign>` renders the deck, prints it, validates
the request with `klt sim --dry-run` and exits without submitting or writing
anything — the way to review a change before it costs fleet time.

## Read this first: what this PDK can and cannot sample

The spec row asks for the untrimmed line "from the **device-mismatch** Monte Carlo
on this core". Before any campaign was run, the question of what a device-mismatch
Monte Carlo even *is* on SG13CMOS5L was settled by measurement, because the model
libraries' own comments do not answer it correctly.

`sim/tools/stat_locality.py` answers it the only way that is sound: instantiate the
**same device twice**, identically sized, in one deck under one model section, force
the same current through both, and compare. Two instances that read identically
share one draw (global, lot-level variation); two that differ were drawn separately
(local, per-instance — mismatch). Each probe is a single `.op` solve, so it runs
locally by design and needs no fleet.

| Section | Measured | Means |
|---|---|---|
| `cornerPNP.lib` `typ` | identical | deterministic, as expected |
| `cornerPNP.lib` `stat` | **identical** | **global only.** `pnpMPA` has *no* per-instance mismatch model anywhere in this PDK |
| `cornerMOShv.lib` `mos_tt` | identical | deterministic, as expected |
| `cornerMOShv.lib` `mos_tt_stat` | **identical** | **global only** — it includes the *non*-mismatch device library |
| `cornerMOShv.lib` `mos_tt_mismatch` | **identical** | **inert**: its per-instance `agauss` calls are gated on the subcircuit parameter `mm_ok`, default `0` |
| the same section with `mm_ok=1` | **different** | the mechanism exists; it is simply unreachable from a `klt sim` request |
| `cornerRES.lib` `res_typ` | identical | deterministic, as expected |
| `cornerRES.lib` `res_stat` | **different** | **local, per instance** — despite the library calling `nsig_*` "global" |

Three consequences, and they are the whole shape of this bench:

1. **The bipolar core cannot be mismatch-sampled at all.** `pnpMPA`'s model card is
   a single global `.model`, parameterised by top-level `.param`s that
   `cornerPNP.lib` `stat` varies with `gauss()`. A `.param` is evaluated once for
   the whole deck, so Q1, Q2 and Q3 receive *the same* draw. The Q1/Q2 emitter-area
   ratio that sets ΔV<sub>BE</sub> — the dominant untrimmed-offset term in any
   bandgap — has no modelled mismatch to sample. This is the risk `CLAUDE.md` names
   ("the central risk is the bipolar device"), arriving exactly where it was
   expected.
2. **MOS mismatch exists but is unreachable.** `sg13g2_moshv_mod_mismatch.lib` does
   carry per-instance `agauss` on `w`, `l`, `delvto` and `factuo` — gated on
   `mm_ok`, whose default is `0` and which the migrated DUT netlist (decision
   record 0006) does not set. `klt sim` offers two ways to turn a PDK's local
   mismatch on without editing the netlist, and neither reaches this PDK:
   `monte_carlo.instances` resolves a *global switch parameter* from a curated
   table covering sky130 and gf180mcu only, and is refused on the `batch` backend
   besides; `monte_carlo.injected` writes `.param mc_inj_*` cards that the netlist
   body has to consume, which a migrated, pinned netlist does not. Opening the gate
   would mean editing the DUT, which is out of scope here by lineage
   (`CLAUDE.md`, "designed once") and would be its own decision record.
3. **Resistor variation *is* local.** `res_stat` gives the `r3_cmc` model card
   non-zero `drsh_*`/`dl_*`/`dw_*` magnitudes against `nsig_*='agauss(0,1,1)'`, and
   ngspice re-evaluates that model-card expression per instantiation. So R1 and R2 —
   the ratio that sets the PTAT gain — are drawn independently. That is genuine
   device mismatch, and it is where this core's untrimmed spread comes from.

So the campaign this bench runs is **global statistical variation of the bipolar and
MOS devices plus local mismatch of the resistors**. It is a real, seeded, controlled
measurement of the untrimmed line, and it is *not* the full device-mismatch Monte
Carlo the row names. The manifest says so: `vref_untrimmed_line_3sigma` is declared
under `spec_rows."6"` with `ratified: false`, so `klt signoff` grades item 6
`partial_coverage`, never `met`. Nothing here is rounded up.

### Why the process-corner axis collapses

T1 item 6 asks for Monte Carlo "combined with (not instead of) process corners".
This PDK does not permit it: statistical sections exist **only at typ**.
`cornerPNP.lib` publishes `typ`, `stat`, `bcs` and `wcs` — there is no `bcs_stat`;
`cornerMOShv.lib` publishes `mos_tt_stat` and no `mos_ss_stat`/`mos_ff_stat`;
`cornerRES.lib` publishes `res_stat` and `res_stat_mismatch` and no `res_wcs_stat`.
Selecting statistics therefore *replaces* the process label rather than qualifying
it, and the five ratified process labels collapse to one statistical point.

The axes that do survive are the ratified ones: **2.97 / 3.30 / 3.63 V × −40 / 27 /
125 °C = 9 points**, each drawn 300 times. That is the honest full grid for this
PDK, not a subset chosen for cost, and the reason is a property of the model
libraries that anyone can check in one `grep`.

## The campaigns

| Campaign | Request | Units | What it is |
|---|---|---|---|
| `line` | `request-mc-line.json` | 9 × 300 = 2700 | the population the spec row is about; cited for item 6 |
| `zero` | `request-mc-zero.json` | 9 × 20 = 180 | the **deterministic control** item 6 asks for in prose |
| `inflated` | `request-mc-inflated.json` | 9 × 100 = 900 | the **known-bad variant** `klt yield` grades as its `negative_control` |
| `families` | `request-mc-families.json` | 4 × 100 = 400 | which device family carries the spread |

All four run the same fixture (`vref-mc.cir.tmpl`) over the same DUT, go to the Spot
batch fleet, and write an append-only `envelopes/<utc>-<sha>.<campaign>.json` plus a
`records/` record of the same name. They differ only in the model sections the
request selects and, for `inflated`, in the scale block the runner generates.

### The deterministic control

`zero` is the line campaign with the three statistical sections swapped for their
deterministic `typ` siblings, which contain no `gauss`/`agauss` call at all. It must
come back with **exactly** zero spread at every point — `stddev == 0.0`, `min ==
max`, not "small" — and `sim/mc-run.sh` exits 7 if any point disagrees. That is what
separates "the model sections produced this spread" from "the harness, the seeding
or the solver produced it".

It carries a second, stronger check for free: with no variation to draw, every point
must land on the number the **item-5 deterministic grid** already recorded at the
same corner. It does, to all six digits, including the ratified nominal 1.19696 V at
typ/3.300 V/27 °C (`sim/closed-loop-vref-pvt`, decision records 0009 and 0011). The
Monte Carlo harness, run with its statistics off, reproduces the corner bench.

One reading trap, stated because the number is in the record: the `zero` campaign's
**pooled** standard deviation is *not* zero. Pooling unions nine different
temperature/supply points, and those points genuinely differ from one another — that
is deterministic corner spread, not sampling spread. The claim is per point, and the
record's `statistics.by_point` is where it is made.

### The known-bad control

`klt yield`'s `negative_control` is a *different thing* from item 6's prose
"deterministic negative control", and this bench carries both rather than letting one
stand in for the other:

- item 6's prose control is `zero` — "the sampler is live", shown by sigma ≡ 0;
- `klt yield`'s control is a **seeded, known-bad variant whose yield must come back
  statistically *worse***, which is what shows the statistics can detect a degraded
  design at all. A zero-spread run cannot be that: it is *better* than nominal, so it
  would come back `not_detected` and read as a finding about the design.

The known-bad variant is `inflated`: the same circuit, same testbench, same window,
every pinned statistical magnitude multiplied by 3 — `yield.md`'s "a mismatch seed
pushed past spec". `klt sim`'s own `monte_carlo.mismatch_scale` does exactly this in
one field, but it resolves a switch from the same sky130/gf180mcu table and rejects
every other family, so the scale is built in the deck instead. `sim/mc-run.sh` reads
each magnitude's nominal value **out of the pinned library** and writes
`.param <name> = <nominal × 3>` after the request's `.lib` cards, where ngspice's
last-definition-wins rule makes it the operative value (measured: a deck-level
`.param` placed after the library does override it; a scale of 0 collapses the draw
to exactly the nominal value). A magnitude that cannot be read at the pin is a hard
error, never a skipped scale — an inflated control that quietly failed to inflate
would come back `not_detected` and look like a design finding.

## The evidence-reporting window

`klt yield` cannot run without `min`/`max`, and **this row has no ratified number**:
its Target column is a method, and the trimmed-line row says in as many words that
it is "not stated as a number until measured". Inventing a bound here would be
ratifying one, which no agent may do.

`yield-limits.json` therefore states a window with no free parameter in it: `min` and
`max` are the smallest and largest `vref` the **deterministic 45-point PVT grid
actually measured** — 1.18874 V at `wcs`/2.970 V/125 °C and 1.20039 V at
`bcs`/3.630 V/−40 °C, read out of the committed envelope the manifest already cites
for `vref_nominal`. Neither endpoint is chosen; both are quoted, and
`sim/tests/test-mc-bench.sh` re-derives them from that envelope on every run, so the
window cannot drift from the measurement it came from.

The question that window asks is a real one — *what fraction of the statistical
population falls inside the deterministic corner envelope the block has already
demonstrated?* — and its answer is what tells the **Trim** row whether a trimmable
offset exists. It is **not** a pass/fail judgement of the design against its spec,
and no yield number produced against it may be read as one. `target_yield` is
deliberately absent for the same reason: a target yield is a claim, and this row has
none to make, so `klt yield` reports the measurement and can never "fail" it.

`target_ci_halfwidth` is 0.02 rather than the 0.01 default, declared in advance: the
campaign is sized to resolve the yield to ±2 percentage points at 95 % confidence,
which 2700 draws deliver at any pass rate (the worst case, p = 0.5, needs
z²·p(1−p)/h² = 2401). The default ±1 pp would need roughly 9600 draws — four times
the fleet time for a precision an unratified row cannot use.

<!-- RESULTS:BEGIN -->
## Results

All **SIMULATED**, ngspice-47, PDK `f7bca32`, `psp103` + `r3_cmc` OSDI, closed loop
with the real amplifier, settled (`vref_settle_v` < 1 mV graded at every one of the
4180 units across the four campaigns; 0 errored, 0 inconclusive). Seed `20261113`,
`seed_scope: point`. Records under `records/`; the cited yield report under `yield/`.

### The untrimmed line

`line` campaign, 9 points × 300 draws = 2700 samples
(`envelopes/20261113T130628Z-e882c25.line.json`):

| | pooled over the 9 points |
|---|---|
| mean `vref` | **1.19485 V** |
| σ | **22.272 mV** (1.86 % of the mean) |
| mean ± 3σ | **[1.12803 V, 1.26166 V]** — width **133.6 mV**, i.e. **±5.59 %** |
| empirical 0.135 / 99.865 percentiles | 1.12260 V / 1.27082 V |
| min / max observed | 1.10783 V / 1.28503 V |

**So the untrimmed line is ±5.6 % (3σ) on this core** — against a deterministic PVT
corner envelope only **11.65 mV** wide. The statistical spread is roughly **11×** the
whole corner spread, which is the finding: for this bandgap, device variation, not
process corner, sets the untrimmed accuracy.

Per point, σ rises monotonically with temperature and barely moves with supply:

| | −40 °C | 27 °C | 125 °C |
|---|---|---|---|
| 2.97 V | 15.72 mV | 20.24 mV | 27.34 mV |
| 3.30 V | 16.34 mV | 19.80 mV | 28.16 mV |
| 3.63 V | 14.99 mV | 21.49 mV | 28.96 mV |

The binding point is **`stat`/3.630 V/125 °C**: mean 1.19111 V, σ 28.96 mV, mean ± 3σ
= [1.10422 V, 1.27800 V].

**The distribution is not normal** and the report says so: Anderson–Darling A² = 3.05
against a 5 % critical value of 0.787 — `rejected` — with excess kurtosis 0.66, i.e.
heavier tails than a Gaussian. The parametric ±3σ above therefore *understates* the
real tails slightly; the empirical 0.135/99.865 percentiles in the table are the
honest pair to quote beside it. This is reported, not corrected for: a 3σ figure is
what the spec row asks for, and what its fit is worth is part of the evidence.

### Where the spread comes from

`families` campaign, 4 × 100 draws at 3.300 V / 27 °C — one family's statistical
section on at a time (`envelopes/20261113T130110Z-d384aed.families.json`):

| Statistical family | σ(`vref`) | share |
|---|---|---|
| `pnpMPA` (`cornerPNP.lib stat`, global) | 1.443 mV | small |
| HV MOS (`cornerMOShv.lib mos_tt_stat`, global) | **0.031 mV** | negligible |
| resistors (`cornerRES.lib res_stat`, **per instance**) | **18.76 mV** | dominant |
| all three together | 22.52 mV | — |

**Do not read 18.76 → 22.52 mV as a clean decomposition.** The three single-family
figures add in quadrature to 18.8 mV, not to the 22.52 mV measured with all three on.
At N = 100 per campaign the two differ by about **1.8 standard errors**
(σ/√(2(N−1)) ≈ 1.6 mV on the combined run, 1.3 mV on `res_stat`), so the gap may be
sampling noise rather than a real cross-family term; this campaign cannot tell the two
apart. Larger N would be needed to say.

The untrimmed line is **resistor-mismatch dominated**, by more than an order of
magnitude over the next contributor. That is consistent with the circuit: R1 and R2
are both `rppd`, and `res_stat` draws them independently, so the R1/R2 ratio that
sets the PTAT gain carries the error directly. It is also why the bipolar gap matters
less here *for this measurement* than it might have — but only by accident, and the
missing term is still missing: `pnpMPA`'s 1.443 mV is its **global** spread, not the
Q1/Q2/Q3 matching error, which has no model to sample at all.

### The controls

**Deterministic (zero-spread).** `zero` campaign, 9 points × 20 draws
(`envelopes/20261113T125843Z-d384aed.zero.json`): `stddev` exactly `0.0` and
`min == max` at **all nine** points, and each point's value equals the one the
deterministic item-5 grid recorded at the same corner, to all six digits — including
the ratified nominal **1.19696 V** at typ/3.300 V/27 °C. The spread the `line`
campaign reports is the model sections' and nothing else's.

**Known-bad (3× sigma).** `inflated` campaign, 9 points × 100 draws
(`envelopes/20261113T130254Z-d384aed.inflated.json`): pooled σ **68.93 mV**, which is
**3.06×** the `families` `stat_all` σ — the deck-level scale demonstrably reached the
draws. Graded by `klt yield` against the same window, its yield is **7.67 %
[6.01, 9.60]** against the nominal's **23.67 % [22.07, 25.32]**: the intervals do not
overlap, so the verdict is **`detected`**. The statistics do catch a degraded design.

### The `klt yield` report (cited for T1 item 6)

`yield/20261113T130628Z-e882c25.line.yield.json`, produced by **klt 0.9.1** with the
`[yield]` extra (`yield/…line.yield-record.json` records the build, every input and
its sha256):

| | |
|---|---|
| window (evidence-reporting, **not** a spec value) | [1.18874 V, 1.20039 V] |
| yield, empirical (Clopper–Pearson) | **23.67 %**, CI [22.07 %, 25.32 %] at 95 %, N = 2700 |
| Cpk / σ-to-spec | 0.0829 [0.0702, 0.0957] / 0.249 [0.211, 0.287], limiting side upper |
| sample size | **sufficient** — required 1735, drawn 2700, observed CI half-width ±1.62 pp against the ±2 pp declared |
| negative control | **detected** |
| status | `reported` — no `target_yield` is declared, so nothing was claimed and nothing failed |

Read it as: **about three quarters of dice land outside the corner envelope**
untrimmed. A Cpk of 0.08 against that window is not a verdict on the design — the
window is 11.65 mV wide and nobody ratified it — it is the quantitative statement
that corner-level accuracy is unreachable without a trim.

### What this says to the Trim row

`spec/target-spec.md` makes the Trim row conditional: *"a trim is ratified only if the
untrimmed MC shows a trimmable offset; if it does not, the Trim row falls back to
'none'."*

**A trimmable offset is indicated, not demonstrated**, and this bench does **not**
edit the Trim or trimmed-line rows.

What this campaign measured:

- The spread is **device-drawn and large**: **about ±67 mV (±5.6 %) at 3σ** pooled,
  ±87 mV if sized on the worst point's 3σ. That is the range a trim would have to
  cover.
- It comes from a **resistor ratio drawn once per die**, not from drift — the
  `families` attribution puts σ = 18.76 mV on `res_stat` alone.
- But **per-point σ scales with temperature**, about 1.8× across the range:

  | Supply | −40 °C | 27 °C | 125 °C |
  |---|---|---|---|
  | 2.97 V | 15.72 mV | 20.24 mV | 27.34 mV |
  | 3.30 V | 16.34 mV | 19.80 mV | 28.16 mV |
  | 3.63 V | 14.99 mV | 21.49 mV | 28.96 mV |

  (σ of `vref_v` per point, N = 300 each, from this bench's `line` envelope.)
  Growth roughly in proportion to absolute temperature is the signature of a **gain
  error on the PTAT term** — consistent with the R1/R2 attribution above — not of a
  temperature-independent offset.

What this campaign did **not** measure: per-die `vref(T)`. `monte_carlo.seed_scope`
is `point`, so each of the nine points draws its own 300 dice and no sample index is
the same die at two temperatures. Whether an additive correction set at 27 °C removes
the spread over −40…125 °C therefore does not follow from these numbers, and in any
case depends on what a trim network adjusts — none exists here. A campaign sharing
one seed across the temperature axis would give per-die `vref(T)` directly; that is
follow-up work, not part of this bench.

Sizing and ratifying a trim network is separate work with its own decision record.

### One number that is easy to misread

The `zero` campaign's **pooled** σ is 3.058 mV, not zero. Pooling unions nine
different temperature/supply points, which genuinely differ from one another — that is
deterministic corner spread, not sampling spread. The zero-spread claim is per point,
and `statistics.by_point` in the record is where it is made.
<!-- RESULTS:END -->

## Files

| File | Role |
|---|---|
| `bench.json` | campaign metadata: the four campaigns, their requests and scales, the graded measurement, and the statistical magnitudes `mc-run.sh` may scale |
| `vref-mc.cir.tmpl` | the deck body — deliberately the same fixture as `sim/closed-loop-vref-pvt/vref.cir.tmpl` |
| `request-mc-*.json` | the four committed, host-portable `klt sim` requests |
| `yield-limits.json` | the `klt yield` spec-limits file and the evidence-reporting window |
| `envelopes/` | append-only raw `klt sim --format json` envelopes — the artifacts `klt yield` consumes |
| `records/` | append-only records: the pin, the hashes, the seed and N, the fleet job ids, the per-point statistics and the control verdict |
| `yield/` | the derived two-population sample set, the `klt yield` JSON report cited for item 6, and its text rendering |

Shared with the rest of `sim/`: `env.sh` (the pin), `runner-lib.sh` (tool gates, the
pin, DUT staging, the one way a request reaches the fleet), `tools/cm5_record.py`
(hashes and the append-only write), `tools/stat_locality.py` (the locality probe).

**A note on size before you re-run anything.** These envelopes are large because a
Monte Carlo envelope carries one entry per *draw*, not per corner: the `line`
campaign's is 8.5 MB for its 2700 units and the four together are about 14 MB in the
working tree (far less in the pack — git compresses them roughly 20×). They are
committed in full and unedited because they are the raw result, and
`options.keep_artifacts` is already `false`, so there is nothing left to trim that is
not evidence. Re-running `line` adds another 8.5 MB rather than replacing it:
`envelopes/` and `records/` are append-only, and `sim/mc-run.sh` refuses to overwrite.
Re-run a campaign when there is something new to measure, not to tidy.

## Friction filed

`klt sim`'s two mechanisms for controlling per-instance mismatch —
`monte_carlo.mismatch_scale` and `monte_carlo.instances` — both resolve a PDK's
switch parameter from a curated table that covers two families, so a third family
gets neither, and `instances` is refused on the `batch` backend besides. The same
curation gap makes `environment.monte_carlo.family_mismatch` report `active: null`
for every family of such a request, so a campaign cannot even observe whether a
family is live without a hand-built two-instance probe. Filed generically at
[`2AMLogic/klayout-tools#5486`](https://github.com/2AMLogic/klayout-tools/issues/5486).

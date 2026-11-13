# 0013: The statistical Monte Carlo bench — which model sections, which window, and what the untrimmed-line row may be read as

- **Status**: ratified, effective when the PR for issue #31 merges
- **Date**: 2026-11-13
- **Decided by**: Loom Builder agent, issue #31

> **Numbering note.** This record was written as `0012` on the issue #31 branch,
> before [`0012`](0012-post-layout-pex-extraction-gap.md) (issue #32, post-layout
> PEX extraction gap) merged to `main` and took that number. It was renumbered to
> `0013` when the two branches merged.
>
> The renumber was applied to this record and to the **living documents** that
> cite it (`README.md`, `manifests/README.md`, `manifests/sg13cmos5l-bandgap.json`,
> `sim/README.md`, `sim/closed-loop-vref-mc/README.md`, `spec/target-spec.md`).
>
> It was deliberately **not** applied inside `sim/closed-loop-vref-mc/`'s campaign
> artifacts — `bench.json`, `request-mc-line.json`, `request-mc-families.json`,
> `yield-limits.json`, `records/*.json` — which still read "decision record 0012"
> and mean *this* record. Those bytes are either append-only evidence or inputs
> whose sha256 is recorded inside that evidence (`request_sha256` in each
> `records/*.json`, the `limits` hash in the yield record), so editing them would
> make a committed record describe bytes that were never simulated. `CLAUDE.md`'s
> rule that `sim/` results are append-only evidence is the reason the prose there
> is frozen at the number the campaign ran under.

## Context

`spec/target-spec.md` §PVT closes with an explicit deferral:

> The Monte Carlo mismatch-section choice is still **open**. … which of the MOS
> and resistor sections the mismatch benches use is a bench decision (#31), not
> settled here.

This record makes that decision, and two others that could not be separated from
it: the window `klt yield` is run against, and what the resulting numbers may be
read as.

T1 **item 6** ("statistical claims carry Monte Carlo evidence") is graded
`unmet` / `no_evidence` in `manifests/sg13cmos5l-bandgap.signoff.json`. It asks
for a recorded seed and sample count, a deterministic negative control, results
combined with (not instead of) process corners, and a `klt yield` report — a
yield estimate with its confidence interval, sample-size verdict and
Cpk / sigma-to-spec against the row's own limits.

The row the item is about, `vref_untrimmed_line_3sigma`, reads: *"untrimmed line
(3σ) from the **device-mismatch** Monte Carlo on this core"*, binding conditions
*"All 5 process corners × −40/27/125 °C × 2.97/3.30/3.63 V; mismatch MC at each
corner point"*. It states **no number**, by construction: the adjacent
trimmed-line row says it is "not stated as a number until measured", and
[`0001`](0001-target-spec-ratification.md)'s rule is that a figure which reads
"derived" is not a ratified number.

## What was measured before deciding

The section choice cannot be made by reading the libraries: their own comments
are wrong about the mechanism in the one case that matters. `sim/tools/stat_locality.py`
settles it by measurement — the same device instantiated twice, identically
sized, under one section, at one operating point; two instances that read
identically share one draw, two that differ were drawn separately.

| Section | Measured | Reading |
|---|---|---|
| `cornerPNP.lib` `stat` | identical | **global only**; `pnpMPA` has no per-instance mismatch model anywhere in this PDK |
| `cornerMOShv.lib` `mos_tt_stat` | identical | **global only** — the section includes the *non*-mismatch device library |
| `cornerMOShv.lib` `mos_tt_mismatch` | identical | **inert**: its per-instance `agauss` terms are gated on the subcircuit parameter `mm_ok`, default `0` |
| the same section, `mm_ok=1` | different | the mechanism exists and works; it is unreachable from a `klt sim` request |
| `cornerRES.lib` `res_stat` | **different** | **local, per instance** — the `r3_cmc` model card's `nsig_*='agauss(0,1,1)'` is re-evaluated per instantiation, despite the library calling it global |

Two further facts about the library set, both checkable in one `grep`:

- **Statistical sections exist only at typ.** `cornerPNP.lib` publishes `typ`,
  `stat`, `bcs`, `wcs` and no `bcs_stat`; `cornerMOShv.lib` publishes
  `mos_tt_stat` and no `mos_ss_stat` / `mos_ff_stat`; `cornerRES.lib` publishes
  `res_stat` / `res_stat_mismatch` and no cornered statistical variant.
- **The `*_mismatch` sections are reachable only by editing the netlist.**
  `klt sim`'s `monte_carlo.instances` resolves a global switch parameter from a
  table curated for sky130 and gf180mcu, and is refused on `batch` besides;
  `monte_carlo.injected` requires the netlist body to reference `mc_inj_*`
  parameters, which the migrated DUT (decision record 0006) does not. Filed
  generically as [`klayout-tools#5486`](https://github.com/2AMLogic/klayout-tools/issues/5486).

## Decision

### 1. The sections: `cornerPNP.lib stat` + `cornerMOShv.lib mos_tt_stat` + `cornerRES.lib res_stat`

This is the only combination that samples anything at all for this DUT, and the
`res_stat` half is genuine per-instance mismatch of the resistors — the R1/R2
ratio that sets the PTAT gain. It is adopted *because it is what exists*, not
because it is sufficient, and §4 records the difference.

The `*_mismatch` sections are **rejected**: selected as the request stands they
sample exactly zero, so adopting them would publish a campaign that reports
"mismatch on" and measures nothing. Opening their `mm_ok` gate means editing a
migrated, pinned netlist; that is out of scope by lineage (`CLAUDE.md`,
"designed once") and would need its own record.

### 2. The grid: the statistical axis replaces the process axis

Because statistical sections exist only at typ, selecting them *replaces* the
process label rather than qualifying it, and the five ratified process labels
collapse to one statistical point. The campaign therefore runs the ratified
supply and temperature axes in full — 2.97/3.30/3.63 V × −40/27/125 °C = **9
points**, N = 300 each — and no process-corner axis.

This is a **declared shortfall against item 6's "combined with (not instead of)
process corners"**, not a cost-saving subset. The item's requirement is not met
and is not claimed to be; the reason is a property of the pinned model
libraries.

### 3. The window is quoted, not chosen; and no `target_yield` is declared

`klt yield` refuses a measurement with no `min`/`max`, and this row ratifies
none. The window in `sim/closed-loop-vref-mc/yield-limits.json` is therefore the
**smallest and largest `vref` the deterministic 45-point PVT grid actually
measured** — 1.18874 V and 1.20039 V, read out of the envelope
[`0011`](0011-corner-verification-pvt-grids.md) already cites for the
`vref_nominal` row. Neither endpoint is chosen; both are quoted, and
`sim/tests/test-mc-bench.sh` re-derives them from that envelope on every run.

It is an **evidence-reporting window, not a spec value**. The question it asks —
what fraction of the statistical population falls inside the deterministic
corner envelope the block has already demonstrated — is well posed and is what
the **Trim** row needs answered. No yield number produced against it is a
judgement of the design against its spec. `target_yield` is deliberately absent:
a target yield is a claim, and this row has none to make.

`target_ci_halfwidth` is declared in advance as 0.02 — ±2 percentage points of
absolute yield at 95 % confidence, which 2700 draws deliver at any pass rate
(worst case p = 0.5 needs 2401). The ±1 pp default would need roughly 9600
draws for a precision an unratified row cannot use.

### 4. Row classification, and what item 6 is declared to cover

`spec/target-spec.md`'s rows split into **statistical** and **non-statistical**
exactly as its own Monte Carlo column already says, and the manifest declares
the statistical set under `spec_rows."6"`:

| Row | Class | Why |
|---|---|---|
| `vref_untrimmed_line_3sigma` | **statistical** | a 3σ spread over a device population; a corner matrix cannot express it |
| `vref_trimmed_line` | **statistical** | the same spread after a modelled trim |
| `vref_nominal` | non-statistical | one value at one binding point; graded by item 5 |
| `tc_endpoint`, `tc_box` | non-statistical | a slope over a temperature sweep at each deterministic corner |
| `psrr_dc` | non-statistical | a ratio of two DC solves at each deterministic corner |
| `iq` | non-statistical | a settled current at each deterministic corner |
| `startup_self_starting`, `startup_time` | non-statistical | a release transient at each deterministic corner |
| `trim` | non-statistical **itself** | its Monte Carlo column is "no": the trim network's range and resolution are *derived from* the untrimmed statistical result, but the row's own evidence is a deterministic monotonicity sweep |
| `supply` | non-statistical | met by construction (device rating), per the spec |
| Area, Signoff | not graded here | a layout cell and the DRC/LVS/ERC decks; T1 items 2, 3 and 4 |

Item 6's declared row set is therefore the two statistical rows:

- `vref_untrimmed_line_3sigma` — covered by this bench's `klt yield` report and
  declared **`ratified: false`**. The campaign measures the row's quantity, but
  the limit it is graded against is an evidence-reporting window rather than a
  ratified bound, and the mechanism the row names (device mismatch) is only
  partly reachable: resistor mismatch yes, bipolar and MOS mismatch no.
- `vref_trimmed_line` — declared a **gap**: it needs a trim network this design
  does not contain.

So item 6 grades `unmet` / `partial_coverage`, with `unratified_rows` and
`declared_gaps` naming both. That is the honest verdict, and it is **not**
upgraded by this record. What changes is that the item moves from
`no_evidence` — nothing measured, nothing said — to a published campaign with
its controls, its seed, its sample size and its own stated limits.

### 5. Two negative controls, because the term means two things

- Item 6's prose asks for a **deterministic negative control** — the sampler is
  live. That is the `zero` campaign: the same deck with the statistical sections
  swapped for their deterministic `typ` siblings, which must report `stddev`
  exactly `0.0` and `min == max` at **every** point. `sim/mc-run.sh` exits 7 if
  any point disagrees.
- `klt yield`'s `negative_control` field is a **seeded known-bad variant** whose
  yield must come back statistically *worse*. A zero-spread run cannot be that —
  it is better than nominal, so it would read `not_detected` and `klt signoff`
  would render item 6 `unmet` / `negative_control_not_detected`, a finding about
  the design rather than about the control. The known-bad variant is the
  `inflated` campaign: every pinned statistical magnitude multiplied by 3,
  generated from the pinned libraries at render time so the inflated sigmas
  cannot drift from the pin.

Both are committed. Neither stands in for the other.

## Alternatives considered

- **Run the ratified 5 × 3 × 3 = 45-point grid with mismatch at each point.**
  Not possible: no statistical section exists at `bcs`/`wcs`/`sf`/`fs`. Pairing
  `res_stat` with a deterministic PNP/MOS corner was considered and rejected —
  it would silently substitute typ-centred resistors for the ratified
  `res_bcs`/`res_wcs` sections, i.e. report a corner the request did not run.
- **Adopt the `*_mismatch` sections anyway**, since they are the ones the spec
  table's Mismatch row gestures at. Rejected: measured to sample exactly zero
  for this netlist. A campaign that reports mismatch on and varies nothing is
  worse than no campaign.
- **Edit the DUT netlist to set `mm_ok=1`.** Rejected here as out of scope
  (`CLAUDE.md`, "designed once"); it is a real option for a future record, and
  the locality probe already shows it works.
- **Choose a round accuracy window** (±1 %, ±5 % of nominal). Rejected: that is
  ratifying a number, which `CLAUDE.md` forbids an agent to do.
- **Declare a `target_yield` so the report has a pass/fail.** Rejected for the
  same reason, and because `klt yield` is explicit that a measurement with no
  target is *reported*, never failed — which is the correct treatment of an
  unratified row.
- **Declare no negative control at all.** Permitted (`klt signoff` records
  `not_declared` and still grades `met`), and rejected: the whole point of item
  6's self-report is to show the statistics can detect a degraded design.
- **Request a spec decision record setting the window instead of measuring.**
  Rejected as premature: the Target this row needs is a *measured* 3σ figure,
  and §6 below is the first measurement of it. A number proposed before the
  mechanism gaps above are closed would be ratifying the gaps along with it.

## Consequences

- `spec/target-spec.md`'s `vref_untrimmed_line_3sigma` row moves from
  `target-only` to a status that cites this record, states the measured 3σ
  figure as **SIMULATED** evidence, and states what it is not. No Target,
  Fallback or Stretch value is edited.
- The §PVT mismatch-section paragraph's open deferral to #31 is replaced by a
  pointer to this record.
- `manifests/sg13cmos5l-bandgap.json` gains `evidence."6"` and
  `spec_rows."6"`; item 6 moves from `unmet` / `no_evidence` to `unmet` /
  `partial_coverage`.
- The **Trim** row is **not** edited, and its condition — "a trim is ratified only
  if the untrimmed MC shows a trimmable offset" — is **not** declared met. §6
  records what this campaign does and does not show: a trimmable offset is
  *indicated* (a large, resistor-drawn per-die spread) but *not demonstrated*
  (per-point σ scales with temperature, and per-die `vref(T)` was never sampled).
  Acting on it (a trim network, its range and resolution), or measuring per-die
  `vref(T)` with a temperature-shared seed, is a separate issue and a separate
  record.
- Closing the two mechanism gaps — bipolar mismatch, and the `mm_ok` gate — is
  tracked outside this record: the tool half at
  [`klayout-tools#5486`](https://github.com/2AMLogic/klayout-tools/issues/5486),
  the PDK half as a model fact that belongs upstream of this repo.

<!-- MEASURED:BEGIN -->
## 6. What it measured

All **SIMULATED** (ngspice-47, PDK `f7bca32`, closed loop with the real amplifier,
settled at every unit; 0 errored, 0 inconclusive across 4180 units). Seed
`20261113`. Full tables, the per-point breakdown and the controls are in
`sim/closed-loop-vref-mc/README.md`; the figures the spec row needs are:

- **The untrimmed line is ±5.59 % (3σ)**: pooled over 9 points × 300 draws,
  mean `vref` = **1.19485 V**, σ = **22.272 mV**, mean ± 3σ =
  **[1.12803 V, 1.26166 V]** (width 133.6 mV). Binding point `stat`/3.630 V/125 °C:
  σ = 28.96 mV, mean ± 3σ = [1.10422 V, 1.27800 V]. The distribution's normality is
  **rejected** (Anderson–Darling A² = 3.05 vs 0.787, excess kurtosis 0.66), so the
  empirical 0.135/99.865 percentiles — 1.12260 V / 1.27082 V — are reported beside
  the parametric window rather than instead of it.
- **For comparison, the whole deterministic §PVT corner envelope is 11.65 mV wide.**
  The statistical spread is roughly **11×** it. On this core, device variation and
  not process corner sets the untrimmed accuracy.
- **It is resistor mismatch**, measured one family at a time at the nominal point:
  σ = 18.76 mV from `res_stat` alone, 1.443 mV from `cornerPNP.lib stat`, 0.031 mV
  from `mos_tt_stat`, 22.52 mV from all three. R1 and R2 are both `rppd` and
  `res_stat` draws them independently, so the ratio that sets the PTAT gain carries
  the error directly. The `pnpMPA` figure is its **global** spread; the Q1/Q2/Q3
  matching term is still absent, not small.
- **Both controls held.** The deterministic control reports σ exactly `0.0` at all
  nine points *and* reproduces the item-5 grid's value at every one of them, to six
  digits, including the ratified nominal 1.19696 V. The known-bad control (3× sigma,
  pooled σ 68.93 mV = 3.06× nominal) grades **`detected`**: 7.67 % [6.01, 9.60]
  against the nominal's 23.67 % [22.07, 25.32], intervals disjoint.
- **The cited `klt yield` report** (klt 0.9.1 with the `[yield]` extra) reports
  yield **23.67 %** CI [22.07 %, 25.32 %] at 95 %, N = 2700, against the
  evidence-reporting window; Cpk 0.0829, σ-to-spec 0.249; sample size **sufficient**
  (required 1735, drawn 2700, observed half-width ±1.62 pp against the ±2 pp
  declared); status `reported`, because no `target_yield` is declared.

### The Trim row's condition: indicated, not demonstrated

`target-spec.md` makes the Trim row conditional on "the untrimmed MC showing a
trimmable offset". This campaign **indicates** one without demonstrating it, and this
record does **not** edit the Trim or trimmed-line rows — their status, Target and
Fallback stay exactly as ratified.

Measured, and pointing toward a trimmable offset: the spread is device-drawn and
large — **about ±67 mV (±5.6 %) at 3σ pooled**, ±87 mV if sized on the worst point —
and the attribution puts it on a **resistor ratio** (σ = 18.76 mV from `res_stat`
alone), i.e. a quantity drawn once per die rather than drift.

Measured, and arguing against the simple reading: per-point σ is not constant over
temperature. From the `line` envelope (σ of `vref_v`, N = 300 per point):

| Supply | −40 °C | 27 °C | 125 °C |
|---|---|---|---|
| 2.97 V | 15.72 mV | 20.24 mV | 27.34 mV |
| 3.30 V | 16.34 mV | 19.80 mV | 28.16 mV |
| 3.63 V | 14.99 mV | 21.49 mV | 28.96 mV |

σ grows about 1.8× from −40 °C to 125 °C, roughly in proportion to absolute
temperature — the signature of a gain error on the PTAT term, not of a
temperature-independent offset.

Not measured at all: per-die `vref(T)`. `monte_carlo.seed_scope` is `point`, so the
nine points draw nine independent sets of 300 dice and no sample index tracks one die
across temperature. "Drawn once per die, therefore removed by a 1-point trim at
27 °C" is consequently an **inference**, not a result of this campaign — and it rests
on a campaign that, as §2 records, cannot sample the Q1/Q2/Q3 matching term at all.
Whether an additive correction set at 27 °C removes the spread over −40…125 °C also
depends on what the trim network adjusts, and no trim network exists.

A campaign sharing one seed across the temperature axis would measure per-die
`vref(T)` directly and settle the question. That is optional follow-up work, not a
condition of this record.

### One grading outcome is the tool's, not the evidence's

With the row declared `ratified: false` and no `target_yield` declared — both correct
— `klt signoff` reports the row under **`uncovered_rows`** as well as
`unratified_rows`, because its item-6 row reader counts only a citation whose report
`status` is `pass`, and a report with no `target_yield` is `status: "reported"`.
Declaring a target the campaign is known to clear would make the row read as covered;
that would be manufacturing a claim to satisfy a grader, so it is not done. The
contradiction — `klt yield` documents `reported` as "no claim was made, nothing
failed" while `klt signoff` reads it as "no evidence exists" — is filed generically as
[`klayout-tools#5490`](https://github.com/2AMLogic/klayout-tools/issues/5490).
Item 6's verdict is `unmet` / `partial_coverage` either way.
<!-- MEASURED:END -->

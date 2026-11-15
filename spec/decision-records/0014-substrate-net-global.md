# 0014: Declare `sub!` global in the item-5 deck fixtures, so the `Vsub` tie reaches the DUT

- **Status**: ratified, effective when the PR for issue #83 merges
- **Supersedes**: item 5 of decision record
  [`0013`](0013-subckt-wrapped-staged-dut.md) ("No `.global sub!` card is
  added") and the matching entry in its "Alternatives considered". Nothing else
  in 0013 is affected, and 0013's text is not rewritten.
- **Date**: 2026-11-13
- **Decided by**: Loom Builder agent, issue #83

## Context

All five T1-item-5 benches carry the card

```
Vsub sub! vss dc 0
```

and a fixture comment describing it as "the substrate net `sub!` (the
rppd/rhigh bulk net in the source) tied to vss through a 0 V source". **It did
not tie them.** `!` is an **xschem** global-net marker; ngspice has no such
convention, and `design/sg13cmos5l/netlist/bandgap_top.spice` carries no
`.global` card. So `XR1`/`XR2` (`rppd`, inside `.subckt bandgap_core`) and
`XRPU` (`rhigh`, inside `.subckt bandgap_startup`) had their bulk terminals on
**per-instance local** nodes — `xdut.xx1.sub!` and `xdut.xx3.sub!` — which are
different nodes from the top-level `sub!` that `Vsub` drives, with no
deliberate DC path. What resolved them was `.options rshunt=1e9`, a convergence
aid.

0013 measured this and recorded it (0013 "What was measured": the bulks "have
**never** been the node `Vsub sub! vss dc 0` drives, on either deck"), then
left it alone on purpose — tying them changes the operating condition every
recorded item-5 figure was taken under, which is not a drive-by edit inside
another issue. 0013 said so explicitly ("out of scope here … filed separately
rather than fixed in passing"). This record is that filing.

**It is a migration artefact, confirmed at the pinned source.** All four
`sg13cmos5l` benches pinned in `reuse.lock.json` from
`2AMLogic/sg13g2-bandgap` @ `52535387e6ccf0a89f6490901a9abb2b78144176` —
`sim/sg13cmos5l-closed-loop-startup/`,
`sim/sg13cmos5l-closed-loop-startup-pex/`,
`sim/sg13cmos5l-core-open-loop-bias/` and
`sim/sg13cmos5l-startup-trip-point/` — **inline every DUT device at the top
level** of their `testbench/*.body.spice.tmpl`. None carries a `.subckt`, an
`.include` of a netlist, or a `.global` card; the only `.lib`/`.include` cards
in any of them are the three PDK corner libraries. So `sub!` really is one
top-level net there (`XR2 sns2 e2 sub! rppd …` sits in the same scope as
`Vsub sub! vss dc 0`), and the source's comment — "The core's rppd bulk
terminals reach the global substrate net `sub!`; tied to vss through a 0 V
source" — is **true of the source**. **No finding is filed on
`sg13g2-bandgap`**: the source has no defect here. The tie stopped reaching
when these decks moved to `.include`-ing the hierarchical migrated netlist
(decision record 0006) and the comment travelled with it unchanged.

The schematics agree with the source's reading: `body=sub!` is on all three
resistor symbols (`design/sg13cmos5l/bandgap_core.sch:140,161`,
`design/sg13cmos5l/bandgap_startup.sch:62`), i.e. one design-wide substrate
net. So does the extracted leg, which ties the resistor bulks to `vss`.

## Decision

**1. Each of the five item-5 deck templates carries one `.global sub!` card**,
placed immediately above the `Vsub sub! vss dc 0` line it makes true:

| Bench | Template |
|---|---|
| `closed-loop-vref-pvt` | `vref.cir.tmpl` |
| `closed-loop-vref-pvt-boxtc` | `deck.cir.tmpl` |
| `closed-loop-psrr` | `deck.cir.tmpl` |
| `closed-loop-iq` | `deck.cir.tmpl` |
| `closed-loop-startup` | `deck.cir.tmpl` |

A global net ignores subcircuit depth, so one card at deck level makes the
leaf resistors' bulk terminals and the top-level `sub!` one net, through the
0013 `.subckt sg13cmos5l_bandgap_top` wrapper, with no change to the netlist
or to the wrapper.

**2. The card lives in the deck fixture, not in `cm5_stage_dut`.** A fixture
choice stays visible in the fixture, where the comment that describes it and
the `Vsub` card it completes already are, rather than being injected inside the
DUT derivation 0013 owns. `sim/runner-lib.sh`'s `cm5_stage_dut` is unchanged
apart from its comment, which previously said staging deliberately adds no such
card.

**3. This supersedes item 5 of 0013 only.** 0013 item 5's reasoning was
correct for #80's scope — the wrapper neither causes nor cures the untied
bulks, and tying them inside #80 would have moved #80's own baseline. It is
superseded here because this record does the thing 0013 deferred: it ties them
**and** re-takes the five grids so the figures that rest on the new operating
condition are measured, not reasoned about. 0013 is not rewritten (`TEMPLATE.md`:
"Do not rewrite a ratified record; supersede it") and keeps its own status line.

**4. No ratified bound, row, criterion or `expected_failure` entry changes.**
`spec/target-spec.md` is untouched. No `expected_failure` block is added,
removed or retuned: `closed-loop-psrr` still declares its 24-of-45 failure
against the ratified Target and still reproduces it exactly.

**5. Nothing under `design/` is edited.** The alternative of adding a `sub!`
pin to the leaf subcircuits would edit the lineage-pinned, item-1-attested
netlist and its schematics; see "Alternatives considered".

**6. The check is mechanical, not a comment.**
`sim/tests/test-grid-benches.sh` gains three per-bench checks: a deck that
drives `sub!` with a `Vsub` card must declare `sub!` global; the `Vsub` card
must be present for the global card to make true; and a `.global` card may name
`sub!` and nothing else. Three negative controls are recorded in that file's
header comment.

## What was measured

**SIMULATED** throughout. Two kinds of run:

- **Node probes**: one local corner per bench, typ / 27 °C / 3.30 V,
  `ngspice-47`, PDK revision `f7bca32694fe3d58be0cc7d9df4b9f5db7161a14`,
  `klt sim --backend local` followed by `op` + `display` on the corner deck
  `klt sim` generated. Run twice per bench: once with the template at
  `195a026` (pre-change) and once with the template in this change.
- **Grids**: the five committed 45-point (15-point for `-boxtc`) `klt sim`
  requests, on the **Spot batch fleet** through `sim/grid-run.sh`
  (`--wait-for-capacity 600`), at this change's head `a7d8d30`.

### 1. The card is what makes the tie reach — all five benches

`display` after `op`, nodes matching `sub`:

| Bench | Pre-change template (`195a026`) | With `.global sub!` |
|---|---|---|
| `closed-loop-vref-pvt` | `sub!`, `xdut.xx1.sub!`, `xdut.xx3.sub!`, `vsub#branch` | `sub!`, `vsub#branch` |
| `closed-loop-vref-pvt-boxtc` | `sub!`, `xdut.xx1.sub!`, `xdut.xx3.sub!`, `vsub#branch` | `sub!`, `vsub#branch` |
| `closed-loop-psrr` | `sub!`, `xdut.xx1.sub!`, `xdut.xx3.sub!`, `vsub#branch` | `sub!`, `vsub#branch` |
| `closed-loop-iq` | `sub!`, `xdut.xx1.sub!`, `xdut.xx3.sub!`, `vsub#branch` | `sub!`, `vsub#branch` |
| `closed-loop-startup` | `sub!`, `xdut.xx1.sub!`, `xdut.xx3.sub!`, `vsub#branch` | `sub!`, `vsub#branch` |

`v(sub!) = 0.000000e+00` in every case, before and after. Three nodes become
one; the two instance-local nodes are gone, not renamed.

### 2. Per-row delta, per bench, graded rows

New envelope vs the last pre-change envelope (the `*-e36facd.json` set PR #84
recorded on the wrapped DUT — the latest in each bench directory at
`195a026`). Worst case and binding corner are read from the committed records'
`grid.rows`; the bound is the request's own `limits`.

**`closed-loop-vref-pvt`** — `20261113T135709Z-e36facd` -> `20261113T143258Z-a7d8d30`,
`pass` -> `pass`, 45/45 -> 45/45.

| Row | Bound | Worst case (old) | Worst case (new) | Binding corner (old) | Binding corner (new) | Verdict |
|---|---|---|---|---|---|---|
| `vref_settle_v` | max 1 mV | 1.029452e-08 V | 1.603721e-08 V | `wcs/3.630V/-40C` | `wcs/3.630V/-40C` | pass -> pass |

**`closed-loop-vref-pvt-boxtc`** — `20261113T134306Z-e36facd` -> `20261113T142724Z-a7d8d30`,
`pass` -> `pass`, 15/15 -> 15/15.

| Row | Bound | Worst case (old) | Worst case (new) | Binding corner (old) | Binding corner (new) | Verdict |
|---|---|---|---|---|---|---|
| `tc_box_ppm_per_c` | max 50 ppm/°C | 39.1856176695 | 39.1856177120 | `bcs/3.630V/27C` | `bcs/3.630V/27C` | pass -> pass |
| `tc_endpoint_ppm_per_c` | max 50 ppm/°C | 38.7582875645 | 38.7582875989 | `bcs/3.630V/27C` | `bcs/3.630V/27C` | pass -> pass |
| `temp_points` | min 8 | 166 | 166 | `typ/2.970V/27C` | `typ/2.970V/27C` | pass -> pass |

**`closed-loop-psrr`** — `20261113T134433Z-e36facd` -> `20261113T142833Z-a7d8d30`,
`fail` -> `fail`, 21 pass / 24 fail of 45 both times (its declared
`expected_failure`, unchanged).

| Row | Bound | Worst case (old) | Worst case (new) | Binding corner (old) | Binding corner (new) | Verdict |
|---|---|---|---|---|---|---|
| `psrr_db` | min 60 dB | 55.2487468769 dB | 55.2487470021 dB | `wcs/2.970V/125C` | `wcs/2.970V/125C` | fail -> fail |

**`closed-loop-iq`** — `20261113T134743Z-e36facd` -> `20261113T142946Z-a7d8d30`,
`pass` -> `pass`, 45/45 -> 45/45.

| Row | Bound | Worst case (old) | Worst case (new) | Binding corner (old) | Binding corner (new) | Verdict |
|---|---|---|---|---|---|---|
| `iq_a` | max 50 µA | 4.10854033677e-05 A | 4.10854033453e-05 A | `bcs/3.630V/125C` | `bcs/3.630V/125C` | pass -> pass |
| `iq_settle_a` | max 1 µA | 7.57780103044e-13 A | 9.82640923112e-13 A | `wcs/3.630V/-40C` | **`sf/3.630V/-40C`** | pass -> pass |

**`closed-loop-startup`** — `20261113T135532Z-e36facd` -> `20261113T143138Z-a7d8d30`,
`pass` -> `pass`, 45/45 -> 45/45.

| Row | Bound | Worst case (old) | Worst case (new) | Binding corner (old) | Binding corner (new) | Verdict |
|---|---|---|---|---|---|---|
| `dvsns_v` | max 20 mV | 0.000493811905372 V | 0.000493804850186 V | `bcs/2.970V/125C` | `bcs/2.970V/125C` | pass -> pass |
| `det_release_ratio` | max 0.2 | 0.00889723516234 | 0.00889722853210 | `wcs/3.630V/125C` | `wcs/3.630V/125C` | pass -> pass |
| `fb_headroom_v` | min 50 mV | 0.700945321636 V | 0.700945331399 V | `bcs/3.630V/125C` | `bcs/3.630V/125C` | pass -> pass |
| `t_settle_s` | max 1 ms | 1.0e-04 s | 1.0e-04 s | `wcs/2.970V/-40C` | `wcs/2.970V/-40C` | pass -> pass |

The two benches the issue singled out as most likely to carry a bulk current —
`closed-loop-startup` (supply ramp) and `closed-loop-psrr` (a DC perturbation
on `vdd`) — are **stated explicitly above even though nothing moved**:
`startup`'s four graded rows keep their verdicts and their binding corners, and
`psrr_db` keeps its verdict, its binding corner and its 24 failing points.

### 3. No verdict changed. One binding corner moved.

**No graded row's verdict changed on any bench.** `psrr_db` still fails its
ratified Target at the same binding corner and the same 24 of 45 points;
everything else still passes.

**One binding corner moved, and it is named here per the issue's acceptance
criteria: `closed-loop-iq`'s `iq_settle_a`, from `wcs/3.630V/-40C` to
`sf/3.630V/-40C`.** What it is, in full:

- `iq_settle_a` is not an accuracy figure. It is the bench's **settling
  residue** — how far the rail current wanders over the last window of the
  2 ms transient — graded against a 1 µA ceiling purely to catch a run that
  never settled.
- Both worst cases are **six orders of magnitude below the bound**: 7.58e-13 A
  then 9.83e-13 A, against `max 1e-06`. The reported margin is
  9.999992e-07 A before and 9.999990e-07 A after.
- The move is between near-identical numbers. In the pre-change grid the five
  `3.630V/-40C` process corners sat at 7.578e-13 (`wcs`), 7.164e-13 (`sf`),
  7.013e-13 (`typ`), 6.861e-13 (`fs`); in the new grid at 9.826e-13 (`sf`),
  9.600e-13 (`typ`), 9.350e-13 (`fs`), 8.909e-13 (`wcs`). The ordering of a
  set of residues spread over ~10 % at the 1e-13 A level changed. That is
  **which corner reports the largest solver residue**, not where the circuit
  is weakest.
- `iq_a`, the row that actually grades the Iq spec, keeps `bcs/3.630V/125C`
  and changes in the 11th significant digit (4.10854033677e-05 ->
  4.10854033453e-05 A).

**Per the issue's acceptance criteria, this PR stops here for review.** No
ratified bound in `spec/target-spec.md` is edited and no `expected_failure`
entry is added or removed to absorb the move.

### 4. How much every value moved, graded or not

The change is **not bit-identical**, so this is stated per quantity rather
than claimed as a no-op. Across all five new envelopes there are 1485
per-corner measurement values that also exist in the pre-change envelopes;
**561 of them are bit-identical** and the rest move as follows (largest
relative difference per bench and measurement, over all 45 / 15 corners):

| Quantity | Kind | Worst relative difference | Example (corner: old -> new) |
|---|---|---|---|
| `vref_start_v` (startup) | near-zero: `vref` at t=0 | ~1.2 (sign flips) | `bcs/3.300V/125C`: -2.768e-20 -> 1.436e-19 V |
| `iq_settle_a` (iq) | settling residue | ~0.99 | `bcs/3.300V/27C`: 3.243e-15 -> 5.173e-13 A |
| `vref_settle_v` (vref-pvt) | settling residue | ~0.99 | `bcs/3.300V/27C`: 4.441e-11 -> 4.333e-09 V |
| `t_settle_s` (startup) | quantized to the 2 µs transient step | 0.049 | one 2 µs step either way; the set of values spans 74–100 µs before and after |
| `dvsns_v` (startup) | difference of two ~0.78 V nodes | 1.6e-03 | `sf/3.630V/-40C`: 7.37842e-05 -> 7.39023e-05 V |
| `tc_endpoint_ppm_per_c` (boxtc) | ppm/°C from a ~6 mV difference | 2.4e-04 | `sf/3.300V/27C`: 33.7196 -> 33.7113 ppm/°C |
| `det_final_v`, `det_release_ratio` (startup) | small node voltage | 3.9e-05 | `sf/3.630V/-40C` ratio: 7.74883e-04 -> 7.74910e-04 |
| everything else, incl. `vref_*`, `iq_a`, `psrr_db`, `fb_*`, `sns*`, `tc_box_ppm_per_c` | absolute node voltages and currents | <= 1.4e-06, most <= 1e-08 | `iq_a` worst: 1.2e-08 relative |

Read it this way: the three order-unity movers are **near-zero or quantized
quantities** — a residue, a t=0 voltage of order 1e-19 V, and a settle time
reported on a 2 µs grid — where a relative difference is meaningless and the
absolute difference is far inside every bound. The largest move of a genuine
physical figure is `dvsns_v` at **0.16 %** — 118 nV on a 73.9 µV difference of
two ~0.78 V sense nodes, at one corner, against a 20 mV bound; the next is
`tc_endpoint_ppm_per_c` at **0.024 %** at one corner, with the grid's worst
case (the graded number) moving in the 10th significant digit. Absolute node
voltages and currents — including every number any spec row grades — agree to
at least six significant digits and usually eight or more.

That is the expected signature of a circuit whose bulk terminals carry no net
DC current but whose Newton iterations now see two fewer `rshunt`-resolved
nodes: the solution is the same to the precision anything is graded at, and
the path to it is not identical.

## Alternatives considered

- **Add a `sub!` pin to the leaf subcircuits.** Rejected: it edits
  `design/sg13cmos5l/netlist/bandgap_top.spice` and its schematics, which
  decision record 0006 holds byte-for-byte to the pinned source and
  `attest/item1.json` re-checks. CLAUDE.md's "designed once" puts that on
  `2AMLogic/sg13g2-bandgap` if anywhere — and the source does not need it
  (see "Context": its benches inline the DUT, so its `sub!` is already one
  net).
- **Declare the floating bulk correct and fix only the comments.** Rejected:
  it leaves every item-5 figure resting on `.options rshunt=1e9`, which is a
  convergence aid, and it disagrees with both the schematics' `body=sub!` and
  the extracted leg, which ties the resistor bulks to `vss`. The issue is
  honest that no number is demonstrably wrong today; the point is that the
  margin was unquantified. It is now quantified.
- **Inject the card in `cm5_stage_dut`.** Rejected: it hides a fixture choice
  inside the DUT derivation, where a reader of the deck would not find it, and
  it would put a deck-fixture decision inside the staging step 0013 owns.
- **Keep 0013 item 5 and record the untied bulks as a permanent caveat.**
  Rejected: the suite would still not catch a corner where the `r3_cmc` bulk
  terminal does carry current, which is the whole risk the issue names.
- **Tighten or remove `rshunt` instead.** Rejected and out of scope: it would
  change the convergence behaviour of all five benches without making the
  intended connection, and `rshunt`/`gmin` are carried over from the source
  body deliberately.
- **Re-grade `iq_settle_a` or widen its bound** so the binding corner is
  stable. Rejected: a settle criterion six orders inside its bound does not
  need a new bound, and relaxing a ratified bound to tidy a report is exactly
  what CLAUDE.md forbids. The move is reported instead.

## Consequences

- The five decks now do what their comments say. Seven comment sites were
  reworded to match: the five fixture comments, the five `rshunt` comments
  (which no longer leave `rshunt` as the only thing holding the bulk nodes),
  `sim/closed-loop-vref-pvt/README.md`, and `cm5_stage_dut`'s comment in
  `sim/runner-lib.sh`.
- Item-5 evidence is re-taken rather than reasoned about: five fresh
  append-only envelopes and records on the batch fleet, plus one single-corner
  local `closed-loop-vref-pvt/run.sh` record (`vref_v = 1.19696 V`,
  typ / 27 °C / 3.30 V, as in decision record 0009). No existing envelope or
  record is edited or removed. The manifest's five item-5 citations move to
  the new envelopes and `manifests/sg13cmos5l-bandgap.signoff.json` is
  regenerated; item 5 still grades `unmet` / `failed_rows: ["psrr_dc"]`.
- The five deck templates are item-9 inventoried, so `evidence/item9.json` is
  regenerated at the 0.8.0 pin and the signoff record with it. The manifest's
  item-9 `content_hash` pins `attest/item9.json`, which is unedited, so it
  does not move.
- A deck that drives `sub!` without declaring it global now fails
  `sim/tests/test-grid-benches.sh` offline. The pre-#83 state of all five
  decks is exactly what that check now rejects, which is the point: no
  simulated value revealed it.
- The schematic leg and the extracted leg now agree about the resistor bulks,
  which removes one difference ahead of #32's item-7 delta.
- The Monte Carlo deck of #31 / PR #82 is **not** covered. PR #82 was still
  open when this landed, and its `sim/closed-loop-vref-mc/vref-mc.cir.tmpl`
  carries the same `Vsub sub! vss dc 0` line. When it merges it needs the same
  card; its committed sample set predates it, and re-running that set is a
  follow-up, not part of this record.

# Roadmap

A CMOS bandgap voltage reference on IHP SG13CMOS5L, ported from
`sg13g2-bandgap`'s SG13CMOS5L branch and graded against the klayout-tools T1
checklist; the PDK and the tools are the variable, not the design.

Status as of 2026-11-13, `main` @ `90a05ff`.

This file says what comes next and why. The verdict of record stays
[`manifests/sg13cmos5l-bandgap.signoff.json`](manifests/sg13cmos5l-bandgap.signoff.json),
per-row evidence stays in [`spec/target-spec.md`](spec/target-spec.md), and the
label-derived queue stays in [`WORK_PLAN.md`](WORK_PLAN.md). Where they
disagree with this file, they win. Tracker: #5 (its checklist table was derived
on 2026-10-17 and predates everything below).

## Where it stands

`klt signoff` at the `klt` 0.8.0 pin grades **4 of 11** T1 items `met`.

| # | Item | Verdict | Evidence or gap |
|---|---|---|---|
| 1 | Design sources | unmet / `no_evidence` | Sources and netlists migrated (`design/sg13cmos5l/`, record `0006`, PR #40); `klt netlist --check` reports `drifted` on all four cells, so `attest/item1.json` is not cited. #26 |
| 2 | Layout | **met** | `evidence/item2.json`; top GDS regenerated from `layout/*/generate.py` (record `0007`, #27) |
| 3 | DRC clean | **met** | `layout/sg13cmos5l-bandgap_top/drc.json`, `clean`; the signoff record quotes 6 rule-free layers and 24 skipped rules (#28) |
| 4 | LVS clean | unmet / `no_evidence` | No `klt lvs` report is committed. #29 |
| 5 | Corner verification | unmet / `check_failed` | Five 45-point closed-loop grids (record `0011`, PR #72; re-taken in PRs #84, #85). Six rows pass; `psrr_dc` fails its Target at 24 of 45 points; four rows are declared gaps |
| 6 | Monte Carlo | unmet / `no_evidence` | Bench in review: #31, PR #82 |
| 7 | Post-layout | unmet / `check_failed` | `sim/pex-bandgap-top/` extraction committed (record `0012`, PR #79); it holds 17 devices against 20 cards because the curated deck extracts no `pnpMPA`, so no delta exists. #32 |
| 8 | Characterization report | unmet / `no_evidence` | Not started. #33 |
| 9 | Testbenches shipped | **met** | `evidence/item9.json` (#34) |
| 10 | Repo hygiene | **met** | `evidence/item10.json` (#35); `pnpm -s test` runs the `sim/tests/` suites (PR #76) |
| 11 | Power delivery | unmet / `no_evidence` | No `klt erc` supply spec or report. #36 |

Simulated results at the ratified Target column (`spec/target-spec.md`, all
closed loop, schematic netlist): TC worst 39.186 ppm/°C box (< 50, met); Iq
worst 41.085 µA (< 50, met); startup settles in 100 µs worst case (< 1 ms,
met); `vref` 1.19696 V at typ / 27 °C / 3.30 V. **PSRR @ DC misses**: worst
55.249 dB at `wcs` / 2.97 V / 125 °C against > 60 dB, failing at every 2.97 V
point and 9 of 15 at 3.30 V. Nothing is measured in silicon.

## Now

Startable today. None of these carries `loom:issue` yet.

1. **Land the Monte Carlo bench (item 6).** #31, PR #82, currently
   `loom:changes-requested`. Done when `sim/closed-loop-vref-mc/` and its
   `klt yield` report are on `main` and the signoff record grades item 6 on a
   citation. The PR itself reports that the result is resistor-mismatch
   dominated and is not the full device-mismatch run the spec row names, so
   item 6 will not grade `met` from it; see Later.
2. **Attribute the PSRR @ DC miss.** No issue yet (seed 1). Done when a
   committed bench record under `sim/` and a decision record name the limiting
   mechanism at the failing points with saved operating-point figures (loop
   gain, mirror and amplifier headroom at 2.97 V), all labelled simulated. No
   design edit and no spec edit in that PR.
3. **Smoke-runner key diff after the runner-lib refactor.** #47, `loom:curated`,
   released from its park on 2026-11-13 when the workers reached ngspice 47.
   Done when one `sim/smoke/run_smoke.sh` run at the `klt` 0.8.0 pin is diffed
   by key against `sim/smoke/records/20261027T020953Z-8327ada.json` and the
   result is posted on the issue. PR #89 already committed two post-fix records
   that show the expected one-key difference.
4. **Correct the README status paragraph.** No issue yet (seed 2). It still
   says "Nothing is laid out, extracted or measured in silicon here", while
   the layout, DRC reports and a post-layout extraction are on `main`, and the
   repo-layout tree omits `attest/` and `evidence/`. Done when the paragraph
   agrees with the signoff record and `evidence/item10.json` is regenerated
   (README is in the item-10 hygiene inventory).

## Next

- **Item 4, LVS (#29).** Parked on #26. The klayout-tools gates it named are
  closed as read today (#3094, #4309, and #4927, which names `klt lvs` with
  the `klayout-runset` engine as the supported route to a match with
  `pnpMPA`). Done when a `klt lvs` report per cell and for the top is
  committed against `design/sg13cmos5l/netlist/`, either `match` and cited, or
  failing with each gap attributed to a filed klayout-tools issue. Open point
  for re-curation: whether the run must wait for item 1's freshness check or
  can run against the committed netlists now, and whether the 0.8.0 pin
  carries the runset grading.
- **Item 11, power delivery (#36).** Parked on #29. Done when an ERC supply
  spec (vdd, vss, substrate and well ties) and a clean `klt erc` report for
  `bandgap_top` are committed and cited with the item-4 report. The ERC half
  does not need the LVS result and could be split out.
- **Item 7, post-layout delta (#32).** Unblocked by klayout-tools#5481 (an
  extraction engine that reaches devices only the PDK runset recognises) and a
  `klt` pin move to the release that carries it. Done when the extracted
  netlist holds all three `pnpMPA` cards, `klt pex` reports for the five
  item-5 benches are committed under `sim/pex-bandgap-top/`, and the item-7
  citation points at them.
- **PSRR design response.** Unblocked by Now 2. Done when either a design
  change with its own decision record brings `psrr_dc` to 45/45 at Target, or
  the finding is filed on `sg13g2-bandgap` as the source of the circuit.
  Relaxing the row is not an option agents hold (`0011`, rejected alternatives).
- **Item 8, characterization report (#33).** Unblocked by #31 and #32. Done
  when one report covers every ratified row with value, binding corner,
  verdict and evidence link, and item 8 grades `met`.

## Later

- **A device-mismatch Monte Carlo that samples the bipolar and MOS pairs.**
  First question: can the `mm_ok`-gated mismatch sections be reached from a
  `klt sim` request, and does the PDK carry any per-instance `pnpMPA`
  mismatch model at all? PR #82 reports no to both at the current pins.
- **Trim network and the trimmed-line and Trim rows.** First question: does
  the untrimmed result show a trimmable offset? The spec makes the Trim row
  fall back to "none" if it does not.
- **Area budget.** The spec sets it "after the first assembled floorplan";
  that floorplan exists (`layout/area.json`, 248.0 × 135.514 µm bounding box).
  First question: what budget is ratified. A spec decision, not agent work.
- **1.2 V LV-device supply stretch.** First question: does an LV-flavour
  re-derivation of the core and amplifier belong here or in `sg13g2-bandgap`.

## Blocked and waiting

- **#26 (item 1)** waits on a decision: regenerate the four netlists at this
  repo's PDK pin (new bytes, so the simulation evidence would be re-taken), or
  have the `mm_ok=1` delta classified so the committed bytes pass. The
  `bandgap_amp` port-order difference noted there is an xschem 3.4.4 against
  3.4.7 export difference; a re-attempt should netlist with 3.4.7.
- **#32 (item 7)** waits on klayout-tools#5481, open as read today. #5477 and
  #5479 are closed.
- **#66, #67, #81** are removal proposals held for an operator decision;
  #74 is a standing digest issue, not work.

## Not planned

- A redesign of the core. The block is designed once in `sg13g2-bandgap`; a
  cell changes here only by migration with a decision record.
- A PSRR frequency point, or any row whose evidence would rest on MoM
  capacitor spread: the models carry none, so such a row is
  `insufficient-evidence` (`spec/target-spec.md`).
- Routing around a deck gap. A device the SG13CMOS5L deck cannot check or
  extract is filed on klayout-tools, not waived.
- Evidence above T1, or silicon characterization: the pinned `klt signoff`
  reports the higher tiers as `tier_not_supported`, and `measurements/` is empty.

# closed-loop-psrr-op

**Why the `psrr_dc` Target is missed** (issue #93). `sim/closed-loop-psrr/` records that the
ratified **PSRR @ DC** Target of `spec/target-spec.md` (> 60 dB) fails at 24 of its 45 points,
worst 55.249 dB at `wcs`/2.970 V/125 °C. It records the miss; nothing committed said what
limits it. This bench measures the operating point that grid solved and attributes the miss to
it. Every figure is **simulated**.

**This bench grades nothing.** Its request carries no `limits` and no `spec_row` tag, no
manifest item cites it, and `spec_rows` in `bench.json` is empty. The ratified bound, the row's
Status and `sim/closed-loop-psrr/` as the row's cited evidence are all untouched — a bench that
explains a miss must not also be scored as evidence that the miss is smaller. Its envelope's
`status: pass` means *every one of the 12 points returned a value for all 141 declared
measurements*, nothing more.

| File | Role |
|---|---|
| `bench.json` | Metadata `sim/grid-run.sh` reads: criteria text, OSDI objects, the empty `spec_rows` and why it is empty |
| `deck.cir.tmpl` | Deck body — **card-for-card byte-identical** to `../closed-loop-psrr/deck.cir.tmpl` |
| `request-grid.json` | The committed, host-portable `klt sim` request: 12 points, three DC `op` solves each, 141 measurements |
| `records/`, `envelopes/` | Append-only evidence, on the same terms as the PVT grids (`../README.md` §PVT grids) |

```bash
source sim/env.sh && sim/grid-run.sh closed-loop-psrr-op
```

No new runner: `sim/grid-run.sh <bench-directory-name>` is generic — it reads `bench.json` for
the deck template, the request, the OSDI objects and the record's criteria text — so this is the
sixth bench directory it serves and the first that is not a T1 item-5 grid.

## What it runs, and why that is still DC-only

The row is **DC, no frequency point** (`../closed-loop-psrr/README.md` says why: a frequency
point would depend on compensation-capacitor values whose MoM models carry no corner or
mismatch spread, which is `insufficient-evidence`, not a pass). So there is **no `ac` analysis,
no frequency point and no loop-break deck** here either. Three DC `op` solves per point:

| Step | `Vpsrr` | What it is |
|---|---|---|
| `lo` | −0.05 V | The PSRR bench's own first solve, same alter, same order |
| `hi` | +0.05 V | The PSRR bench's own second solve |
| `op` | 0 V | Back to the deck default. A 0 V source is a DC short, so this is the **unperturbed** bias the secant was taken about |

`lo` and `hi` are the committed grid's two solves, which is why `psrr_db` here is the same
secant and must reproduce that grid's number (it does — below). `op` is where the attribution
data comes from: all 14 MOS devices' `vgs`, `vds`, `vdss`, `gm`, `gds` and `ids`.

### Two PDK facts the bench had to work around

- **`klt sim --op-lint` cannot address this PDK's devices at all.** It is the obvious
  instrument for per-device saturation margins. On SG13CMOS5L every value comes back `null`
  with `region: "unknown"` and an `op_point_unavailable` diagnostic: the PDK's
  `.subckt sg13_hv_pmos` wraps an OSDI (PSP103) `N` instance, the lint probes only
  `@m.<path>.<element>`, and the documented `op_lint.models.*.op_point_element` override
  substitutes the element name but not the `@m.` prefix. Filed as generic tool friction at
  [`2AMLogic/klayout-tools#5637`](https://github.com/2AMLogic/klayout-tools/issues/5637); this
  bench does not wait on it, and instead writes the `@n.<path>[...]` expressions by hand into
  ordinary `measurements[].expr` entries.
- **There is no `vdsat` on this PDK.** PSP103's name for the saturation voltage is `vdss`;
  `save @n.…[vdsat]` fails with *"vector is not available or has zero length"*. The issue's
  `vds − vdsat` margin is therefore recorded as **`|vds| − |vdss|`** — the same quantity under
  the model's own name. The magnitudes make one expression correct for both channel types,
  because PSP103 reports device-oriented quantities.

### The 12 points, and why these 12

`corners` is a cross product, so a bench cannot name three arbitrary points. This one is
process {`typ`, `wcs`} × supply {2.970, 3.300, 3.630} V × {27, 125} °C, chosen so that **each
(process, temperature) pair appears at all three supplies** — the supply dependence is the
question, so within each such triple vdd is the only thing that moves. It contains all three
points the issue requires: the worst failing point `wcs`/2.970 V/125 °C, a passing 3.63 V point
(all four of them pass), and `typ`/3.300 V/27 °C. Six of the 12 fail the ratified Target in the
committed grid and six pass.

## Result (SIMULATED, batch fleet, 2026-11-14)

Envelope `envelopes/20261114T055319Z-21bfd3c.json`, record
`records/20261114T055319Z-21bfd3c.json`, ngspice-47, `klt 0.9.2.dev1022+g2a9c52b27ce7`,
PDK `f7bca32…` (15 model files staged and hash-matched by the worker; see `../README.md`).
12/12 points returned a value for all 141 measurements — no `null`, no diagnostic, nothing
errored or inconclusive.

### AC 3 — the PSRR figures reproduce the committed grid

`psrr_db` here is the same ±0.05 V secant as `sim/closed-loop-psrr/`, so it is a check on the
deck and the request, not a new result. **Both numbers**, at all 12 shared points:

| Corner | This bench | `closed-loop-psrr` grid | Δ |
|---|---|---|---|
| `typ`/2.970 V/27 °C | 56.240480966 dB | 56.240480627 dB | +3.4e-07 dB |
| `typ`/3.300 V/27 °C | 59.442607202 dB | 59.442606123 dB | +1.1e-06 dB |
| `typ`/3.630 V/27 °C | 66.795112827 dB | 66.795112797 dB | +3.1e-08 dB |
| `typ`/2.970 V/125 °C | 55.740750499 dB | 55.740750501 dB | −2.2e-09 dB |
| `typ`/3.300 V/125 °C | 62.742765656 dB | 62.742765915 dB | −2.6e-07 dB |
| `typ`/3.630 V/125 °C | 65.164093369 dB | 65.164091963 dB | +1.4e-06 dB |
| `wcs`/2.970 V/27 °C | 55.857622261 dB | 55.857622308 dB | −4.6e-08 dB |
| `wcs`/3.300 V/27 °C | 58.816403513 dB | 58.816403314 dB | +2.0e-07 dB |
| `wcs`/3.630 V/27 °C | 65.497361094 dB | 65.497361070 dB | +2.4e-08 dB |
| **`wcs`/2.970 V/125 °C** | **55.248747002 dB** | **55.248746877 dB** | +1.3e-07 dB |
| `wcs`/3.300 V/125 °C | 61.366853660 dB | 61.366852628 dB | +1.0e-06 dB |
| `wcs`/3.630 V/125 °C | 67.469995979 dB | 67.469993886 dB | +2.1e-06 dB |

Grid values from `../closed-loop-psrr/envelopes/20261113T115930Z-0be5a53.json`, the envelope
`manifests/` cites. Agreement is to 8 significant figures — the largest disagreement is
2.1 × 10⁻⁶ dB. They are not bit-identical because the `op` solves here are not the only two in
the deck: the steps are cumulative, so `lo` starts from a different initial guess than it does
in the grid. `vref` at `typ`/3.300 V/27 °C is 1.196960 V, the figure
`../closed-loop-psrr/README.md` and decision record 0009 both quote.

### The mechanism

Full argument, the arithmetic and what it rules out: decision record
[`0015`](../../spec/decision-records/0015-psrr-dc-attribution.md). In short, per 100 mV of rail:

| Corner | psrr (dB) | Δvref (µV) | ΔI<sub>M3</sub> (nA) | from `gds` (nA) | from `gm` (nA) | required over-track (ppm) | delivered (ppm) | delivered/required |
|---|---|---|---|---|---|---|---|---|
| `typ`/2.970 V/27 °C | 56.240 | +154.2 | +1.626 | +4.643 | −3.020 | 981.6 | 637.5 | 0.649 |
| `typ`/3.300 V/27 °C | 59.443 | +106.6 | +1.091 | +4.358 | −3.267 | 920.1 | 689.1 | 0.749 |
| `typ`/3.630 V/27 °C | 66.795 | +45.7 | +0.382 | +4.180 | −3.771 | 881.4 | 794.8 | 0.902 |
| `typ`/2.970 V/125 °C | 55.741 | +163.3 | +1.690 | +5.088 | −3.399 | 1120.2 | 747.3 | 0.667 |
| `typ`/3.300 V/125 °C | 62.743 | +72.9 | +0.696 | +4.708 | −4.011 | 1034.8 | 880.9 | 0.851 |
| `typ`/3.630 V/125 °C | 65.164 | **−55.2** | **−0.742** | +4.468 | −5.176 | 980.3 | 1136.5 | **1.159** |
| `wcs`/2.970 V/27 °C | 55.858 | +161.1 | +1.515 | +4.210 | −2.697 | 972.7 | 622.2 | 0.640 |
| `wcs`/3.300 V/27 °C | 58.816 | +114.6 | +1.047 | +3.957 | −2.911 | 912.9 | 670.8 | 0.735 |
| `wcs`/3.630 V/27 °C | 65.497 | +53.1 | +0.404 | +3.800 | −3.371 | 875.5 | 776.2 | 0.887 |
| **`wcs`/2.970 V/125 °C** | **55.249** | **+172.8** | +1.596 | +4.604 | −3.009 | 1107.4 | 722.5 | 0.652 |
| `wcs`/3.300 V/125 °C | 61.367 | +85.4 | +0.735 | +4.267 | −3.530 | 1024.5 | 846.9 | 0.827 |
| `wcs`/3.630 V/125 °C | 67.470 | **−42.3** | **−0.550** | +4.055 | −4.574 | 971.9 | 1096.8 | **1.128** |

`ΔI_M3` is `dids_m3_a`, measured; the two columns beside it are `dids_m3_gds_term_a` and
`dids_m3_gm_term_a`, the only two terms XM3's own measured `gm` and `gds` predict for it. Their
sum (`dids_m3_predicted_a`) matches the measured value to 0.03–0.20 % at the eight points where
the residual is appreciable, and to 4.5–7.1 % at the four 3.63 V points where it is a 0.4–0.7 nA
difference of two ≈ 4 nA terms. "Required over-track" is `gds_M3/gm_M3`, the amount by which
`fb` would have to out-run the rail for the two terms to cancel exactly; "delivered" is the
measured `fb_tracking − 1`. **PSRR is the residual of that near-cancellation**, which is why
Δvref changes sign at the two 3.63 V/125 °C points — the sign flip
`../closed-loop-psrr/README.md` notes but does not explain.

The output branch impedance that converts that residual current into Δvref is measured, not
inferred from geometry: `r1_ohm` = (`vref` − `e3`)/`ids(M3)` is **83.9–95.6 kΩ** across the 12
points (`r2_ohm`, the PTAT resistor, is 11.07–12.61 kΩ), and `rbranch_ohm` − `r1_ohm` leaves
**11.0–20.6 kΩ** for `XQ3`'s own slope at the eight well-conditioned points. That is about
twice the 5.2–6.0 kΩ an ideal diode's `VT/I` would give, which is consistent with `pnpMPA`'s
near-unity current gain making base current a first-order term (`CLAUDE.md`) — noted as
consistent, not established: this bench does not separate base current from the device's
internal resistances.

### Saturation margins, and the negative one

| Quantity | Worst over the 12 points | Where |
|---|---|---|
| `\|vds\| − \|vdss\|`, minimum over the **12 signal-path devices** | **+0.4162 V** (`mn2`) | `typ`/2.970 V/125 °C |
| `msense_marg_v` | −0.1638 V | `typ`/2.970 V/27 °C |
| `mkfb_ids` | 1.4 × 10⁻¹⁴ … 4.8 × 10⁻¹¹ A | — |

All 12 signal-path devices (the three mirror PMOS and the nine amplifier devices) are in
saturation with **at least 0.41 V of margin at every one of the 12 points**, including the worst
failing point, and the minimum is supply-independent to four decimals (0.5248 / 0.5249 /
0.5249 V at 2.97 / 3.30 / 3.63 V, `typ`/27 °C). **The miss is not a headroom limit**, and
headroom could not produce a supply dependence here even in principle.

The one negative margin is **by design and is recorded, not suppressed**: `XMSENSE` is the
startup sense device, held in deep triode (`vds` 3.9–32.3 mV) because the latch has released
and `det` sits near `vss`. That is what keeps `XMKFB` off — its `ids` is 5 to 8 decades below
the 4.4–6.4 µA mirror leg — so the startup keeper is ruled out as a competing supply-dependent
mechanism **by measurement**, which is what recording its `ids` and `vds` is for.

### The amplifier's DC gain

| Measurement | Range over the 12 points |
|---|---|
| `av1` — first stage, `gm_MP1 / (gm_MN1 + gds_MN1 + gds_MP1)` | 0.851 … 0.868 V/V |
| `gm2_s` — second-stage transconductance | 89.7 … 112.0 µS |
| `rout_ohm` — output-node resistance, `1/(gds_MN3 + gds_MP4)` | 2.13 … 2.84 MΩ |
| **`av_amp_derived`** = `0.5 · av1 · gm2_s · rout_ohm` | **96.0 … 112.1 V/V (39.6 … 41.0 dB)** |

`av_amp_derived` is the DC gain figure the issue asks for. It is **derived** from the measured
operating point by the textbook two-stage small-signal expression, not directly measured, so
`av1`, `gm2_s` and `rout_ohm` are recorded separately and every device's raw `gm`/`gds` is in
the record — the arithmetic can be redone without re-running the bench. Stated neglects: the
body effect (`gmb`), and the tail-current feedback that comes of `XMTAIL`'s gate being the
amplifier's own output node `fb`. **The first stage's gain is below unity** (a PMOS pair's `gm`
into diode-connected NMOS loads), so all of the ~40 dB is the second stage's.

`fb_per_dvid` (6.3 × 10³ … 8.0 × 10⁴) is recorded beside it and **is not a gain**: it is
|Δfb / Δ(sns2 − sns1)| across the supply secant, i.e. the gain the loop *would* need if the
differential input error were the only thing moving `fb`. It is two to three orders of
magnitude above `av_amp_derived`, which is the measurement that says most of `fb`'s tracking is
not loop-driven at all — the amplifier's own supply-referred bias produces it, since `XMTAIL`,
`XMP3` and `XMP4` have their sources on `vdd`.

## What this bench does not establish

- **The split of the delivered over-tracking** into the amplifier's intrinsic supply-referred
  output shift and the loop's correction. Only their sum is measured. Any DC loop gain quoted
  from the deficit would assume the intrinsic shift is zero, which it is not.
- **0.37–0.64 dB of the four 3.63 V points**, where the attribution's residual is a small
  difference of two ≈ 4 nA terms.
- **`rbranch_ohm`** (the measured Δvref/ΔI_M3, 94.8–116.2 kΩ at the eight well-conditioned
  points) is itself a ratio of two small secant differences, so its 74.4–131.4 kΩ spread at the
  four 3.63 V points is a conditioning artifact, not a real swing — and the bench proves that
  rather than asserting it: `r1_ohm` measures `XR1` directly from the operating point at
  83.9–95.6 kΩ, and `rbranch_ohm` cannot physically be *below* it, yet at two of those four
  points it is (74.4 and 76.9 kΩ). At the eight well-conditioned points `rbranch_ohm − r1_ohm`
  is a consistent 11.0–20.6 kΩ, `XQ3`'s own slope.
- **Mismatch and statistical spread.** All 12 points are nominal process corners; there is no
  Monte Carlo here. The MoM capacitor models carry no corner or mismatch spread (`CLAUDE.md`),
  but nothing at DC depends on them.
- **The other 33 points of the committed grid** (−40 °C, and the `bcs`/`sf`/`fs` corners) are
  not measured here. Their PSRR values in the committed grid follow the same supply ordering.
- **The fix.** Proposing the amplifier change is deliberately out of this bench's scope; it
  belongs to `sg13g2-bandgap`, which owns the circuit by lineage (`CLAUDE.md`).

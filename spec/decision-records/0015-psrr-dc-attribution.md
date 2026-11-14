# 0015: What limits PSRR @ DC — the mirror's output conductance against the amplifier's rail tracking

- **Status**: ratified, effective when the PR for issue #93 merges
- **Date**: 2026-11-14
- **Decided by**: Loom Builder agent, issue #93

## Context

`spec/target-spec.md`'s **PSRR @ DC** row (`psrr_dc`) is a **failed** row of T1
item 5. The committed 45-point grid
(`sim/closed-loop-psrr/envelopes/20261113T115930Z-0be5a53.json`, decision
record [`0011`](0011-corner-verification-pvt-grids.md)) misses the ratified
Target of > 60 dB at 24 points — every point at 2.97 V, 9 of 15 at 3.30 V,
none at 3.63 V — worst **55.249 dB** at `wcs`/2.970 V/125 °C.

`0011` recorded the miss and said, in prose, that "the worst corner is …
where the amplifier's loop gain is lowest" and that "PSRR of a bandgap of this
topology is set by that loop gain". **Nothing committed measured any of that.**
No record held the amplifier's gain, the saturation margin of any mirror or
amplifier device, or the current in the startup keeper, at any failing point.
Without them no design response can be proposed, or handed to
`2AMLogic/sg13g2-bandgap`, which owns the circuit by lineage (`CLAUDE.md`).

This record is the attribution. The measurement is the new bench
`sim/closed-loop-psrr-op/`; this record states what it shows, what it rules
out, and what it does not establish.

## Decision

**1. The mechanism is named, with the figures, and no bound moves.**
`spec/target-spec.md` is untouched — no bound, no Status, no row. No
`expected_failure` entry is added, removed or retuned. `sim/closed-loop-psrr/`
remains the row's only cited evidence and still reports
`failed_rows: ["psrr_dc"]`. Nothing under `design/` or `layout/` is edited.

**PSRR @ DC is set, at every one of the 12 measured points, by how exactly the
amplifier makes `fb` out-run the rail — not by headroom, and not by the
startup leg.** Per 100 mV of rail, the output mirror device `XM3`'s drain
current moves by the sum of exactly two terms built from its own measured
small-signal parameters:

```
dIds(M3) = gds(M3) * (dVdd - dVref)      channel-length modulation: +3.80 .. +5.09 nA
         + gm (M3) * (dVdd - dFb)        the gate drive the amplifier provides:
                                                                   -2.70 .. -5.18 nA
```

The two are of nearly equal size and opposite sign. They cancel exactly when
`fb` over-tracks the rail by precisely `gds(M3)/gm(M3)` — 0.88 to 1.12 mV/V
here. The amplifier delivers 0.62 to 1.14 mV/V, i.e. **64 % to 116 % of what
exact rejection requires**, and the residual, times the measured output-branch
impedance (`XR1` at a directly measured 83.9–95.6 kΩ plus `XQ3`'s own
11.0–20.6 kΩ slope), is the whole of ΔVref:

```
1 / PSRR(linear) = gm(M3) * | gds(M3)/gm(M3) - (dFb/dVdd - 1) | * Rbranch
```

That closed form reproduces the measured `psrr_db` **within 0.07 dB** at the
eight points where the residual is appreciable, and within 0.64 dB at the four
3.63 V points where it is a 0.4–0.7 nA difference of two ≈ 4 nA terms (see
"What was measured" §2).

**The supply dependence is that near-cancellation closing as the rail rises.**
Required over-tracking *falls* ~10 % from 2.97 V to 3.63 V (`gds(M3)` falls as
`Vds(M3)` rises from 1.77 V to 2.44 V) while delivered over-tracking *rises*
~25 %, so the ratio runs 0.64 → 0.90 at 27 °C and 0.67 → 1.16 at 125 °C. At
3.63 V/125 °C it overshoots unity, which is why ΔVref **changes sign** there —
the sign flip `sim/closed-loop-psrr/README.md` noted without explaining.

**2. Headroom is ruled out, by measurement.** All **12 signal-path devices**
(the three mirror PMOS and the nine amplifier devices) are in saturation at
every one of the 12 points, minimum margin `|vds| − |vdss|` = **+0.4162 V**
(`XMN2`, at `typ`/2.970 V/125 °C). The minimum is supply-independent to four
decimals (0.5248 / 0.5249 / 0.5249 V at 2.97 / 3.30 / 3.63 V, `typ`/27 °C), so
headroom could not produce a supply dependence here even in principle. The
original issue's hypothesis — "the supply dependence suggests a
headroom-limited mechanism" — is **not** what the measurement shows.

**3. The startup keeper is ruled out, by measurement.** `XMKFB` carries
1.4 × 10⁻¹⁴ … 4.8 × 10⁻¹¹ A against a 4.4–6.4 µA mirror leg — five to eight
decades down — at every point, because `XMSENSE` is held in deep triode
(`vds` 3.9–32.3 mV) with `det` near `vss`: the startup latch has released and
the keeper is off. `XMSENSE`'s is the one negative saturation margin in the
record (−0.164 … −0.121 V) and it is **recorded as such, by design**, not
clamped or dropped.

**4. The enabling weakness is the amplifier's DC gain, and it is measured to
be ~40 dB.** `av_amp_derived` is 96.0 … 112.1 V/V (**39.6 … 41.0 dB**) over
all 12 points, essentially supply- and corner-independent. Its first stage's
gain is **below unity** — `av1` = 0.851 … 0.868, a PMOS pair's `gm` into
diode-connected NMOS loads (`XMP1`/`XMP2` are `w=20u l=1u`, `XMN1`/`XMN2` are
`w=10u l=1u`, and at 2.47 µA the NMOS still has the higher `gm`: 45.0 µS
against 38.7 µS) — so the whole ~40 dB is the second stage's. A high-gain
amplifier would force the over-tracking to the required `gds/gm` whatever its
own supply-referred shift happened to be; at 40 dB it cannot.

`fb_per_dvid` is recorded beside it, 6.3 × 10³ … 8.0 × 10⁴, and **is not a
gain**: it is `|dFb / d(sns2 − sns1)|` across the secant, the gain the loop
*would* need if the differential input error were the only thing moving `fb`.
Being two to three decades above `av_amp_derived`, it is the measurement that
says most of `fb`'s tracking is **not** loop-driven — the amplifier's own
supply-referred bias produces it, `XMTAIL`, `XMP3` and `XMP4` having their
sources on `vdd`.

**5. The Target is reachable in this topology — but the topology has its own
ceiling, and it is close.** Even with an infinite-gain amplifier the loop
would hold the *input* leg's current, setting the over-tracking to
`gds(M1)/gm(M1)`, while exact rejection at the *output* leg needs
`gds(M3)/gm(M3)`. The two differ because `XM3`'s drain sits at `vref`
(1.19 V) and `XM1`'s at `sns1` (0.78 V), so the two identical devices do not
have identical `Vds`. The irreducible residual is
`gm(M3) · |gds(M3)/gm(M3) − gds(M1)/gm(M1)| · Rbranch`, which gives a ceiling
of **65.2 … 79.8 dB**, worst **65.2 dB** at `wcs`/2.970 V/125 °C. So:

- the ratified 60 dB Target is **not** forbidden by this topology — there is
  10.0 dB of headroom lost to finite gain at the worst point, and closing it
  is an amplifier change;
- but the best this mirror arrangement can do at the worst corner is ~5 dB
  over Target, which a follow-up should weigh before assuming gain alone is
  the answer.

This ceiling is **derived** from measured parameters under an infinite-gain
assumption, not measured. It is stated as a figure to be checked by the
follow-up, not as evidence about the committed design.

**6. No fix is proposed here.** The issue's Out of Scope forbids it and
`CLAUDE.md` puts the circuit on `sg13g2-bandgap`. §7 below lists what a
follow-up would have to establish.

**7. What is NOT established.** Each of these is a limit of this measurement,
stated rather than papered over:

- **The split of the delivered over-tracking** into the amplifier's intrinsic
  supply-referred output shift and the feedback loop's correction. Only their
  sum (`fb_tracking`) is measured. Any DC loop gain quoted from the deficit —
  e.g. `1/(1 − delivered/required) − 1`, which would read 1.8 … 9.2 — assumes
  the intrinsic shift is zero, which §4 shows it is not. **No loop-gain figure
  is claimed by this record.**
- **0.37–0.64 dB of the four 3.63 V points**, where the attributed residual is
  a small difference of two ≈ 4 nA terms.
- **`av_amp_derived` is derived, not measured.** It neglects the body effect
  (`gmb`) and the tail-current feedback that comes of `XMTAIL`'s gate being
  `fb`. `av1`, `gm2_s`, `rout_ohm` and every device's raw `gm`/`gds` are in
  the record so it can be redone or replaced.
- **`Rbranch`** (94.8–116.2 kΩ at the eight well-conditioned points) is itself a
  ratio of two small secant differences; its 74.4 and 76.9 kΩ readings at two of
  the four 3.63 V points are **demonstrably** artifacts, being below the directly
  measured `r1_ohm` (`XR1` alone, 83.9–95.6 kΩ), which is impossible. What the
  bench does **not** separate is base current from `XQ3`'s internal resistances
  inside the 11.0–20.6 kΩ that `Rbranch − r1_ohm` leaves for its slope — about
  twice an ideal diode's `VT/I`, consistent with `pnpMPA`'s near-unity current
  gain but not established by this bench.
- **Mismatch and statistical spread.** All 12 points are nominal process
  corners; there is no Monte Carlo here, and the `pnpMPA`'s near-unity current
  gain enters only through the measured `Rbranch` and branch currents, not as
  a separately quantified term.
- **The other 33 points** of the committed grid (−40 °C, and the `bcs`/`sf`/`fs`
  corners). Their PSRR values in that grid follow the same supply ordering, but
  this record does not extend the attribution to them.
- **Anything at a frequency.** DC only, by the row's own definition.

## What was measured

**SIMULATED.** One 12-point `klt sim` grid on the **Spot batch fleet** through
`sim/grid-run.sh` (`--wait-for-capacity 600`), plus two single-corner local
`klt sim --backend local` probes that confirmed the device-addressing idiom
before the grid was submitted.

- Bench: `sim/closed-loop-psrr-op/`, record
  `records/20261114T055319Z-21bfd3c.json`, envelope
  `envelopes/20261114T055319Z-21bfd3c.json`
- Points: process {`typ`, `wcs`} × supply {2.970, 3.300, 3.630} V ×
  {27, 125} °C = 12 — six of which fail the ratified Target in the committed
  grid and six of which pass, and which include the worst failing point
  `wcs`/2.970 V/125 °C, several passing 3.63 V points, and `typ`/3.300 V/27 °C
- Three DC `op` solves per point: `Vpsrr` = −0.05 V, +0.05 V (the committed
  PSRR bench's own secant, same alters, same order), then `Vpsrr` = 0 V — a DC
  short, so the third solve is the **unperturbed** bias the secant was taken
  about. **No `ac` analysis, no frequency point, no loop break.**
- 141 declared measurements per point; 12/12 points returned a value for every
  one, with no `null` and no diagnostic
- `ngspice-47`, `klt 0.9.2.dev1022+g2a9c52b27ce7`, PDK revision
  `f7bca32694fe3d58be0cc7d9df4b9f5db7161a14`, 15 model files staged from this
  host's pin and hash-matched by the worker (`models_staged.hashes_match: true`)
- The deck is **card-for-card byte-identical** to
  `sim/closed-loop-psrr/deck.cir.tmpl` — verifiable with
  `diff <(grep -v '^\*' sim/closed-loop-psrr/deck.cir.tmpl) <(grep -v '^\*' sim/closed-loop-psrr-op/deck.cir.tmpl)` —
  so the operating point read here is the one that grid solved, not a similar
  one

### 1. The PSRR figures reproduce the committed grid

`psrr_db` here is the same ±0.05 V secant, so this is a check on the deck and
request, not a new result. All 12 shared points agree with
`sim/closed-loop-psrr/envelopes/20261113T115930Z-0be5a53.json` to **8
significant figures**; the largest disagreement is 2.1 × 10⁻⁶ dB. Both numbers
are tabulated per point in `sim/closed-loop-psrr-op/README.md`. At the worst
failing point `wcs`/2.970 V/125 °C: **55.248747002 dB** here against
**55.248746877 dB** in the grid. They are not bit-identical because the steps
are cumulative, so `lo` starts from a different initial guess than it does in
the grid.

### 2. The attribution, point by point

Per 100 mV of rail. `dIds(M3)` is measured (`dids_m3_a`); the two terms beside
it are computed from `XM3`'s own measured `gm` and `gds`
(`dids_m3_gds_term_a`, `dids_m3_gm_term_a`); "sum" is their total
(`dids_m3_predicted_a`); "req"/"got" are `gds(M3)/gm(M3)` and the measured
`fb_tracking − 1`; "formula" is the closed form of §1 of the Decision.

| Corner | psrr (dB) | ΔVref (µV) | ΔI<sub>M3</sub> (nA) | `gds` term | `gm` term | sum (nA) | req (ppm) | got (ppm) | got/req | formula (dB) |
|---|---|---|---|---|---|---|---|---|---|---|
| `typ`/2.970 V/27 °C | 56.240 | +154.2 | +1.626 | +4.643 | −3.020 | +1.623 | 981.6 | 637.5 | 0.650 | 56.217 |
| `typ`/3.300 V/27 °C | 59.443 | +106.6 | +1.091 | +4.358 | −3.267 | +1.091 | 920.1 | 689.1 | 0.749 | 59.408 |
| `typ`/3.630 V/27 °C | 66.795 | +45.7 | +0.382 | +4.180 | −3.771 | +0.409 | 881.4 | 794.8 | 0.902 | 66.160 |
| `typ`/2.970 V/125 °C | 55.741 | +163.3 | +1.690 | +5.088 | −3.399 | +1.688 | 1120.2 | 747.3 | 0.667 | 55.705 |
| `typ`/3.300 V/125 °C | 62.743 | +72.9 | +0.696 | +4.708 | −4.011 | +0.697 | 1034.8 | 880.9 | 0.851 | 62.682 |
| `typ`/3.630 V/125 °C | 65.164 | **−55.2** | **−0.742** | +4.468 | −5.176 | −0.709 | 980.3 | 1136.5 | **1.159** | 65.531 |
| `wcs`/2.970 V/27 °C | 55.858 | +161.1 | +1.515 | +4.210 | −2.697 | +1.512 | 972.7 | 622.2 | 0.640 | 55.833 |
| `wcs`/3.300 V/27 °C | 58.816 | +114.6 | +1.047 | +3.957 | −2.911 | +1.046 | 912.9 | 670.8 | 0.735 | 58.781 |
| `wcs`/3.630 V/27 °C | 65.497 | +53.1 | +0.404 | +3.800 | −3.371 | +0.429 | 875.5 | 776.2 | 0.887 | 64.928 |
| **`wcs`/2.970 V/125 °C** | **55.249** | **+172.8** | +1.596 | +4.604 | −3.009 | +1.595 | 1107.4 | 722.5 | 0.653 | 55.212 |
| `wcs`/3.300 V/125 °C | 61.367 | +85.4 | +0.735 | +4.267 | −3.530 | +0.737 | 1024.5 | 846.9 | 0.827 | 61.308 |
| `wcs`/3.630 V/125 °C | 67.470 | **−42.3** | **−0.550** | +4.055 | −4.574 | −0.519 | 971.9 | 1096.8 | **1.129** | 67.946 |

Read it this way. The measured mirror-leg excursion is accounted for by `XM3`'s
own two terms to **0.03–0.20 %** wherever it is appreciable; the 4.5–7.1 % at the
four 3.63 V points is what a 7 % error in a difference of two ≈ 4 nA terms
looks like, and it is the same three points where the closed form is 0.4–0.6 dB
out. The `got/req` column is the whole story in one number: it is 0.64–0.67 at
every failing 2.97 V point, 0.73–0.85 at 3.30 V, and 0.89–1.16 at 3.63 V.

### 3. Saturation margins — the negative result that matters

`|vds| − |vdss|`, PSP103's `vdss` standing in for the `vdsat` this PDK does not
expose (see "Alternatives considered"):

| Device set | Minimum margin over the 12 points | Where |
|---|---|---|
| Mirror, `XM1`/`XM2`/`XM3` | +1.564 V | `typ`/2.970 V/125 °C (`m3`) |
| Amplifier, 9 devices | **+0.4162 V** (`XMN2`) | `typ`/2.970 V/125 °C |
| Startup, `XMSENSE` | **−0.1638 V** (triode, by design) | `typ`/2.970 V/27 °C |
| Startup, `XMKFB` | +2.02 V (off; `ids` ≤ 4.8 × 10⁻¹¹ A) | `wcs`/2.970 V/27 °C |

Every device in the signal path is in saturation with ≥ 0.41 V of margin at
every point including the worst failing one, and the amplifier minimum changes
by 10⁻⁴ V across the three supplies. **This is the measurement that rules out
the headroom hypothesis**, and it is the reason the bench records all 14 devices
and not only the ones a hypothesis singled out.

### 4. The amplifier

| Measurement | Range over the 12 points |
|---|---|
| `av1` = `gm(MP1)/(gm(MN1) + gds(MN1) + gds(MP1))` | 0.851 … 0.868 V/V |
| `gm2_s` = `gm(MN3) + gm(MP4)·gm(MN4)/(gm(MP3) + gds(MP3) + gds(MN4))` | 89.7 … 112.0 µS |
| `rout_ohm` = `1/(gds(MN3) + gds(MP4))` | 2.13 … 2.84 MΩ |
| `av_amp_derived` = `0.5 · av1 · gm2_s · rout_ohm` | **96.0 … 112.1 V/V (39.6 … 41.0 dB)** |
| `fb_per_dvid` (**not** a gain; see Decision §4) | 6.3 × 10³ … 8.0 × 10⁴ |

## Alternatives considered

- **`klt sim --op-lint --op-lint-corner all` as the margin source.** Rejected
  because it does not work on this PDK, measured: the PDK's
  `.subckt sg13_hv_pmos` wraps an OSDI (PSP103) `N` instance, the lint probes
  only `@m.<path>.<element>`, and `op_lint.models.*.op_point_element`
  substitutes the element name but not the `@m.` prefix — so every value
  returns `null` with `region: "unknown"` and an `op_point_unavailable`
  diagnostic. Filed as generic tool friction at
  [`2AMLogic/klayout-tools#5637`](https://github.com/2AMLogic/klayout-tools/issues/5637)
  per `CLAUDE.md`'s friction protocol; the bench writes the `@n.<path>[...]`
  expressions by hand instead and does not wait on it.
- **`vdsat` as the saturation reference.** Not available: this PDK's MOS
  devices expose `vdss`, PSP103's own name for the saturation voltage, and
  `save @n.…[vdsat]` fails with *"vector is not available or has zero length"*.
  `|vds| − |vdss|` is the same quantity under the model's name. A parameter
  name, not a change to what the issue asks for.
- **An `ac` analysis, or a 1 Hz "DC-equivalent" sweep, to measure loop gain
  directly.** Rejected: the row is DC only and the issue's Out of Scope
  excludes any frequency point. `sim/closed-loop-psrr/README.md` gives the
  substantive reason — a frequency point would depend on compensation-capacitor
  values whose MoM models carry no corner or mismatch spread, which is
  `insufficient-evidence`, not a pass.
- **Reusing the source repo's `sim/loop-gain-phase-margin` bench.** Rejected:
  its break is `Lbreak` + `Vtest … ac 1`, a DC short and an AC open, so it
  yields a figure only under `.ac`.
- **A DC secant across a hand-broken loop**, to measure the amplifier's gain
  directly instead of deriving it. Permitted by the issue's criteria and
  rejected here: it needs a second deck with a `.nodeset`-seeded bias, which
  the source repo's own README documents as convergence-delicate, and it would
  no longer be the operating point the committed PSRR grid solved — which is
  the one thing this bench exists to read. The derived figure is recorded with
  its neglects stated and its inputs preserved instead (Decision §7).
- **Grading the margins** (`limits: {min: 0}` on the 14 margin measurements),
  so a device leaving saturation would fail the envelope. Rejected: `XMSENSE`
  is legitimately in triode, so the natural bound is wrong on its face; and a
  bench whose purpose is to explain a failed row must not introduce bounds of
  its own that could be read as coverage. The bench grades nothing.
- **Adding the bench to `manifests/` item 5 as a sixth citation.** Rejected
  twice over: `sim/tests/test-grid-benches.sh:142` asserts "manifest item 5
  cites exactly the five grid benches", and more importantly a bench that
  explains a miss must not also be scored as evidence that the miss is
  smaller. `spec_rows` in its `bench.json` is empty and no manifest item cites
  it.
- **A second request inside `sim/closed-loop-psrr/`.** Rejected:
  `sim/grid-run.sh` takes one bench directory name and treats `bench.json`,
  the deck template and the request as one unit, and
  `sim/closed-loop-psrr/`'s files are cited by name in `manifests/` and in
  `0011`. A separate directory keeps the cited grid untouched.
- **A new runner.** Rejected: `sim/grid-run.sh` is generic by construction, so
  this is simply the sixth bench directory it serves. `sim/grid-run.sh`,
  `sim/runner-lib.sh` and `sim/tools/cm5_record.py` are unmodified.
- **Full 45 points.** Rejected as unnecessary: the question is the supply
  dependence, and a sub-grid in which each (process, temperature) pair appears
  at all three supplies isolates it while holding the grid small. The three
  points the issue requires are all in it. The 33 unmeasured points are listed
  under Decision §7.

## Consequences

- `psrr_dc` keeps its ratified bound, its measured value and its failed
  Status. What changes is that the miss now has a cause on record, with
  figures, so a design response can be proposed — and `sg13g2-bandgap`, which
  owns the circuit, can be handed a mechanism rather than a number.
- The follow-up it enables is an **amplifier** change (the ~40 dB DC gain,
  whose first stage is below unity), bounded by the derived 65.2 dB
  worst-corner topology ceiling of Decision §5 — which says gain alone buys at
  most ~5 dB over Target at `wcs`/2.970 V/125 °C, so a `Vds`-matching change to
  the mirror leg may be needed with it. Neither is proposed here.
- Two prose claims in `0011` are now measured rather than asserted: "the worst
  corner … is where the amplifier's loop gain is lowest" is **refined** — the
  amplifier's gain is essentially corner- and supply-independent at ~40 dB; what
  varies with supply is the *required* over-tracking against the *delivered*
  one. `0011` is **not** rewritten (`TEMPLATE.md`: do not rewrite a ratified
  record) and nothing in it is superseded: it recorded a miss, which stands.
- The sign flip of `dvref_v` across the grid, which
  `sim/closed-loop-psrr/README.md` records without explaining, is explained: it
  is the near-cancellation crossing.
- `sim/closed-loop-psrr-op/deck.cir.tmpl` and `request-grid.json` are added to
  the T1 item-9 inventory (`attest/item9.json`, 14 → 16 checks), so
  `evidence/item9.json`, the manifest's item-9 `content_hash` and
  `manifests/sg13cmos5l-bandgap.signoff.json` are regenerated at the 0.8.0 pin
  in the same PR. No other verdict in the signoff record moves; item 5 still
  grades `unmet` with `failed_rows: ["psrr_dc"]`.
- One new append-only `sim/smoke/records/*.json`, written by the item-9
  cold start that regeneration runs. No existing record or envelope anywhere
  under `sim/` is edited or removed.
- A tool gap is on file rather than worked around silently
  (`klayout-tools#5637`): `--op-lint` cannot address an OSDI-wrapped device on
  any PDK built this way, not only this one.

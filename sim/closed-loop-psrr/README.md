# closed-loop-psrr

The **PSRR @ DC** row of `spec/target-spec.md` (issue #30, Part of #5): DC power-supply
rejection at all 5 process corners × −40/27/125 °C × 3 supplies = 45 points. Every figure is
**simulated**.

| File | Role |
|---|---|
| `bench.json` | Grid metadata `sim/grid-run.sh` reads: the graded criteria, the spec row id, the OSDI objects |
| `deck.cir.tmpl` | Deck body: `closed-loop-vref-pvt/vref.cir.tmpl`'s fixture plus the `Vpsrr` perturbation handle |
| `request-grid.json` | The committed, host-portable `klt sim` request: 45 units, two DC solves each |
| `records/`, `envelopes/` | Append-only evidence (see `sim/README.md` §PVT grids) |

```bash
source sim/env.sh && sim/grid-run.sh closed-loop-psrr
```

## DC only, and how a derivative fits in one corner unit

The spec row is explicit: **DC, no frequency point.** It says why — a frequency point would
depend on compensation-capacitor values, and the MoM models carry no corner or mismatch spread,
so any such row is `insufficient-evidence`, not a pass. So this bench runs no `ac` analysis:
an `ac` sweep at 1 Hz would be numerically convenient and would still be a small-signal
frequency point.

PSRR is nonetheless a derivative, which needs two solves. The deck adds one element to the
reference bench's fixture:

```
Vvdd  vddsrc 0   dc <supply>     <- the grid's supply point; corners.supply_v alters this
Vpsrr vdd    vddsrc dc 0         <- the perturbation handle; the request's steps alter this
```

`request-grid.json` then uses `analysis_steps`: step `lo` solves an `op` with
`Vpsrr = −0.05 V`, step `hi` solves an `op` with `Vpsrr = +0.05 V`, and the derived
measurement is

```
psrr_db = db( |hi.vdd − lo.vdd| / |hi.vref − lo.vref| )
```

`Vpsrr` must not be a `corners.supply_v` key — `klt sim` refuses a step `alter` of a swept
supply source — which is exactly why the handle is a separate element rather than a second
value of `Vvdd`. A 0 V source is a DC short, so at `Vpsrr = 0` this deck is electrically the
reference bench's deck. Checked before this bench was built, as a single-corner local `ngspice`
probe (not a committed envelope): this deck's cards at typ/27 °C/3.30 V with `Vpsrr = 0` settle
to `vref` = 1.196960 V, the same value to all six reported digits as decision record 0009's
settled transient figure. The committed grid's own typ/3.300V/27C point reports
`lo.vref` = 1.196905 V and `hi.vref` = 1.197011 V, which straddle it as they should.

### Three things that could have made the number wrong, and what guards each

- **Supply excursion.** The two solves sit ±50 mV about each grid supply, so the rail reaches
  3.68 V at the 3.63 V point and 2.92 V at the 2.97 V point — just outside the ratified ±10 %
  operating window. That is disclosed, not hidden: a derivative needs two points, and a secant
  kept inside the window would have to straddle two grid supplies and so could not be reported
  per point. `dvdd_v` is recorded at every point and is 0.1 V at all 45.
- **Resolution.** At 60 dB a 0.1 V secant moves `vref` by 100 µV, which is about ten units of
  ngspice's default six-significant-digit *print* format. The derived measurement is not
  affected — it reads ngspice's stored vectors at full double precision — and
  `ngspice_init` widens `numdgt`/`measureprec` to 12 so the per-step values recorded beside it
  are not rounded either. `dvref_v` is recorded so the secant is auditable.
- **Solver residual.** A 100 µV difference between two Newton solves must not be the solver's
  own tolerance. `options.ngspice_options` tightens `reltol` to 1e-8, `vntol` to 1e-10 and
  `abstol` to 1e-14 for this bench only; all 45 points converge. `psrr_db` also carries a
  `plausible_range` of [0 dB, 140 dB], so a numerically-zero difference masquerading as
  infinite rejection fails instead of being recorded.

`op`, not `tran`: the DC operating point is the correct, non-degenerate closed-loop solution
for this circuit (measured — see `closed-loop-vref-pvt-boxtc/README.md`), and differencing two
settled transients would carry each one's residual into the 100 µV. Each step's `vref` carries
a `plausible_range` of [0.5 V, 2.0 V] so a degenerate solve is failed rather than differenced.

## Result (SIMULATED, batch fleet, 2026-11-13)

Envelope `envelopes/20261113T111443Z-3830083.json`, record
`records/20261113T111443Z-3830083.json`, job `klt-sim-b03a4aec8d12`, ngspice-47,
PDK `f7bca32…` (model text staged and hash-matched; see `sim/README.md`).

**45/45 points pass.** Graded against the ratified **Fallback** bound of > 50 dB:

| Measurement | Worst case | Binding corner | Best case |
|---|---|---|---|
| `psrr_db` | **55.249 dB** | `wcs/2.970V/125C` | 68.330 dB |
| `dvdd_v` | 0.1 V | every point | 0.1 V |
| `dvref_v` | −68.6 µV … +172.8 µV | — | — |

Against the row's other two columns, reported and **not** graded (`bench.json` says why):

| Column | Bound | Worst measured | Verdict |
|---|---|---|---|
| Fallback | > 50 dB | 55.249 dB | **met** (graded) |
| Target | > 60 dB | 55.249 dB | **NOT met** |
| Stretch | > 70 dB | 55.249 dB | not met |

**The PSRR target is missed on measured evidence.** This is the one row of the five where the
ratified Target does not hold at every point, and it is recorded as a miss rather than
accommodated: no bound is edited, and the Target column of `spec/target-spec.md` is unchanged.
The worst corner is the slow/worst-case process at the low supply and high temperature, which
is where the amplifier's loop gain is lowest — PSRR of a bandgap of this topology is set by
that loop gain, and this design carries the source's amplifier unchanged (decision record
0006). Improving it is an amplifier change, which is a design decision outside this issue;
decision record 0011 records the miss and leaves the row's status at the measured value.

`dvref_v` changes sign across the grid (the sense of the residual line sensitivity flips
between corners); `psrr_db` takes its magnitude, which is what the row asks for.

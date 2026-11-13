# closed-loop-iq

The **Iq** row of `spec/target-spec.md` (issue #30, Part of #5): the assembled, self-biased
block's settled quiescent supply current at all 5 process corners × −40/27/125 °C × 3 supplies
= 45 points. Every figure is **simulated**.

| File | Role |
|---|---|
| `bench.json` | Grid metadata `sim/grid-run.sh` reads: the graded criteria, the spec row id, the OSDI objects |
| `deck.cir.tmpl` | Deck body: the same fixture cards as `closed-loop-vref-pvt/vref.cir.tmpl` |
| `request-grid.json` | The committed, host-portable `klt sim` request: 45 units, 2 ms transient each |
| `records/`, `envelopes/` | Append-only evidence (see `sim/README.md` §PVT grids) |

```bash
source sim/env.sh && sim/grid-run.sh closed-loop-iq
```

## What is measured, and why it is the same operating point as the reference

Iq is read as `|i(Vvdd)|` at the end of the 2 ms transient. No ammeter is inserted: `Vvdd` is
already the only path from the rail into the DUT, so its branch current **is** the block's
supply current, and adding a series element would change the deck the reference bench
established. There is no load, because the row is about the self-biased block's own current and
`vref` drives nothing in this netlist.

The deck's cards are the reference bench's cards unchanged, deliberately: an Iq figure is only
meaningful as the current of the *same* settled closed-loop operating point the reference is
read from. `vref_v` is therefore recorded at every point too, with a `plausible_range` of
[0.5 V, 2.0 V], so an Iq number can never be read off a degenerate (zero-current) solution
that happens to sit comfortably under the bound.

The row's **"settled"** qualifier is graded rather than assumed: `iq_settle_a` is the largest
deviation of `|i(Vvdd)|` from its 2 ms value over the last 0.5 ms of the transient, bounded at
1 µA (1 % of the fallback bound).

`rshunt=1e9` is carried over from the reference fixture rather than retuned, and matters enough
here to state: a 1 GΩ shunt from every node to ground adds at most ~3.6 nA to the rail current
at 3.63 V — four orders below the 100 µA bound and below the last reported digit of the
measured Iq.

## Result (SIMULATED, batch fleet, 2026-11-13)

Envelope `envelopes/20261113T111553Z-3830083.json`, record
`records/20261113T111553Z-3830083.json`, job `klt-sim-442d5a006d95`, ngspice-47,
PDK `f7bca32…` (model text staged and hash-matched; see `sim/README.md`).

**45/45 points pass.** Graded against the ratified **Fallback** bound of < 100 µA:

| Measurement | Worst case | Binding corner | Best case |
|---|---|---|---|
| `iq_a` | **41.085 µA** | `bcs/3.630V/125C` | 19.548 µA (`typ/2.970V/-40C`) |
| `iq_settle_a` | 0.758 pA | `wcs/3.630V/-40C` | 2.24 fA |
| `vref_v` | 1.188738 V … 1.200392 V | — | — |

Against the row's other two columns, reported and **not** graded (`bench.json` says why):

| Column | Bound | Worst measured | Verdict |
|---|---|---|---|
| Fallback | < 100 µA | 41.085 µA | **met** (graded) |
| Target | < 50 µA | 41.085 µA | **met** |
| Stretch | < 20 µA | 41.085 µA | not met (the best corner, 19.5 µA, is under it; the worst is not) |

This is evidence against the row, not a new ratified number: the ratified bounds are unchanged.
The binding corner is best-case-speed process at the high supply and high temperature, which is
where the PTAT core current and the amplifier's bias are both largest.

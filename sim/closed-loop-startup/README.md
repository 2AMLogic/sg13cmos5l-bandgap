# closed-loop-startup

The **Startup** row of `spec/target-spec.md` (issue #30, Part of #5): release from `vdd` = 0 at
all 5 process corners × −40/27/125 °C × 3 supplies = 45 points, graded on **self-starting** and
on the **settling time**. Every figure is **simulated**.

| File | Role |
|---|---|
| `bench.json` | Grid metadata `sim/grid-run.sh` reads: the graded criteria, the spec row ids, the OSDI objects |
| `deck.cir.tmpl` | Deck body: the inherited source bench's fixture (200 µs `vdd` ramp, 2 ms window) over the migrated DUT |
| `request-grid.json` | The committed, host-portable `klt sim` request: 45 units, one linearized 2 ms transient each |
| `records/`, `envelopes/` | Append-only evidence (see `sim/README.md` §PVT grids) |

```bash
source sim/env.sh && sim/grid-run.sh closed-loop-startup
```

## Why this bench exists in this tree at all

The Startup row's *planned* testbench is not in this repository: it is the inherited
`sim/sg13cmos5l-closed-loop-startup` of `2AMLogic/sg13g2-bandgap` at the commit in
`reuse.lock.json`, taken by pin (decision record 0002). That bench ran the same 45-point grid
and its source record `20260829-085039-94869af` reports **45/45 points self-starting**. What it
does not contain is a settling **time**: every one of its measurements is a
`.meas ... find ... at=` card at 20 µs or at the 2 ms end point, so the row's `< 1 ms` has no
evidence behind it anywhere — which is exactly what `spec/target-spec.md` says ("The `< 1 ms`
time was not extracted from that record by this plan").

Extracting it needs a measurement the source bench does not have, so **decision record 0011
supersedes the planned bench for this row with this one**. What is carried over unchanged is
the fixture and the criteria; what is added is `t_settle_s`.

### Carried over from the source body, unchanged

- The rail ramps **0 → supply over 200 µs** and holds to 2 ms, so what the simulator solves for
  is the block's own cold-start → closed-loop-settled transition.
- `.options rshunt=1e9 gmin=1e-9`, with the source's reason: the real, not-yet-loop-gain-tuned
  amplifier can fail to converge at an early, near-singular instant on the `vdd` ramp at a
  marginal corner.
- The three **self-starting** criteria, from the source record's own Claim paragraph: the
  startup circuit releases, the real amplifier closes the loop, and `fb` settles to an interior
  equilibrium rather than railing.

### Changed, and why

- **One request carries the whole supply axis.** The source baked the ramp target per supply and
  dispatched one request per supply, because `alter` cannot sweep a PWL source. This bench uses
  `corners.supply_waveforms: ["Vvdd"]`, which rescales the PWL levels per corner (peak → the
  corner's supply) and reports what was simulated per point under `corners[].supply_waveforms`.
  So the committed deck's ramp target is the nominal 3.30 V — the PWL peak the rescaling is
  relative to — not a placeholder.
- **The DUT is the migrated hierarchical netlist.** The source body inlined every DUT device
  verbatim; this deck `.include`s `design/sg13cmos5l/netlist/bandgap_top.spice`, the
  byte-identical migration of decision record 0006.

### What the `Vmkfb` ammeter measured, and what replaces it

The source body inserted a 0 V source (`Vmkfb`) in series with `XMKFB`'s drain to measure the
startup cell's own contribution to the shared `fb` node (`|i(XMKFB)| ≤ 50 nA`). It could do
that because it had inlined the devices. This bench cannot: splitting that net would mean
editing the migrated DUT, which decision record 0006 forbids.

The release is graded on the startup cell's **detect node** instead, through the hierarchical
name `v(xx3.det)` — which is `XMKFB`'s gate drive, and is the source's *other*, equivalent
release criterion (`v(det) ≤ 0.2·vdd`). A released startup cell holds `det` near ground, and
`XMKFB` is then off by construction; the measured worst case is `det/vdd` = 0.0089, i.e. 8.9 mV
of gate drive at 3.63 V, far below the device's threshold. The `|i(XMKFB)| ≤ 50 nA` form of the
criterion is not re-measured here, and the source's record is where it lives.

## The band, and the clock the time is measured from

`< 1 ms` names no band, so this bench states one and grades it:

> `t_settle_s` is the last instant at which `|vref(t) − vref(2 ms)|` exceeded **1 %** of
> `vref(2 ms)`, measured from **t = 0** — the release from `vdd` = 0 — so it **includes the
> 200 µs supply ramp**.

Both choices are the conservative reading: a tighter band and a clock started at `vdd`-valid
would each be easier to pass. `analysis.linearize` resamples the transient onto a uniform 2 µs
grid before the expressions run, so the time has a deterministic 2 µs resolution instead of
depending on where the solver happened to step; every measurement here is an `expr` over those
linearized vectors — no `.meas` cards — so all of them read the same grid. `vref_start_v` is
recorded to show the release really was from zero (worst magnitude over the grid: 5.4e-19 V).

## Result (SIMULATED, batch fleet, 2026-11-13)

Envelope `envelopes/20261113T111658Z-3830083.json`, record
`records/20261113T111658Z-3830083.json`, job `klt-sim-629bfa96b6f0`, ngspice-47,
PDK `f7bca32…` (model text staged and hash-matched; see `sim/README.md`).

**45/45 points pass.**

| Measurement | Bound | Worst case | Binding corner |
|---|---|---|---|
| `dvsns_v` (loop closed) | ≤ 20 mV | **0.494 mV** | `bcs/2.970V/125C` |
| `det_release_ratio` (startup released) | ≤ 0.2 | **0.00890** | `wcs/3.630V/125C` |
| `fb_headroom_v` (not railed) | ≥ 0.05 V | **0.701 V** | `bcs/3.630V/125C` |
| `t_settle_s` | < 1 ms | **100 µs** | `wcs/2.970V/-40C` |
| `time_points` | ≥ 8 | 1001 | every point |

`t_settle_s` spans 74 µs … 100 µs over the grid. It is **shorter than the 200 µs ramp**: the
core reaches its PTAT/CTAT balance while `vdd` is still rising, and `vref` is inside ±1 % of its
final value from then on. That is why the figure is reported with the ramp included — excluding
it would have made the number meaningless here.

Against the row's columns:

| Column | Bound | Measured | Verdict |
|---|---|---|---|
| Fallback | self-starting | 45/45 on all three criteria | **met** (graded) |
| Target | self-starting, < 1 ms | 100 µs worst case | **met** (graded) |

The Startup row is the one row where the graded bound is the **Target**, not the Fallback: its
Fallback column carries no time at all, so grading only the fallback would leave the `< 1 ms`
unexpressed. The other four benches grade their Fallback column; `bench.json` and
`request-grid.json` both say so.

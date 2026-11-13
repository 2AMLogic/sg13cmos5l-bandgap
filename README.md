# sg13cmos5l-bandgap

A CMOS bandgap voltage reference on
[IHP SG13CMOS5L](https://github.com/IHP-GmbH/IHP-Open-PDK), the CMOS-only,
reduced-metal-stack sibling of IHP's SG13G2 130 nm open PDK — designed by AI
agents driving [klayout-tools](https://github.com/2AMLogic/klayout-tools) and
the open-source xschem + ngspice flow.

**Status: specification ratified (issue #2); the schematic is now simulated
across the full PVT corner grid (issue #30,
[`0011`](spec/decision-records/0011-corner-verification-pvt-grids.md)) — seven
of the eleven spec rows carry measured corner evidence, one ratified Target
(PSRR @ DC) is missed on that evidence, and the statistical and trim rows have
none. Nothing is laid out, extracted or measured in silicon here.** The work
starts from the SG13CMOS5L branch already carried in
[sg13g2-bandgap](https://github.com/2AMLogic/sg13g2-bandgap), not from a
blank page.

**Built agent-native.** Every specification, decision record, testbench, and
line of documentation here is produced by AI agents working from a ratified
spec and an append-only evidence trail — not human-authored work that agents
merely assisted with. Verification is the product: every claim traces to a
recorded result under PVT corners. Where the agents hit friction with the
open-source tooling — most often
[klayout-tools](https://github.com/2AMLogic/klayout-tools) — that friction is
filed as a public issue against the tool itself, so the fix benefits everyone
using SG13CMOS5L, not just this repo.

## Why this block, on this PDK

This is a **port, not a new design.** The bandgap is the fleet's most mature
block — [gf180-bandgap](https://github.com/2AMLogic/gf180-bandgap),
[sky130-bandgap](https://github.com/2AMLogic/sky130-bandgap) and
[sg13g2-bandgap](https://github.com/2AMLogic/sg13g2-bandgap) — so the spec
structure, the verification harness and the decision-record trail are known
quantities. The PDK is the variable, not the design.

SG13CMOS5L differs from SG13G2 in exactly the ways that matter to a
reference:

- **No HBT.** The SG13G2 core is built around the `npn13G2` SiGe HBT, which
  SG13CMOS5L does not offer. The only bipolar device is the parasitic
  `pnpMPA`, whose model card puts its current gain near unity. The core
  therefore follows the grounded-collector parasitic-PNP shape of the gf180
  and sky130 bandgaps, as `sg13g2-bandgap`'s decision record 0004 already
  argued.
- **No MIM capacitor.** Compensation and filtering use MoM or MOS
  capacitors only.
- **Shared front-end devices.** The MOS, `pnpMPA` and resistor models are
  the same as SG13G2's, so the device-level reading done in `sg13g2-bandgap`
  carries over directly; what changes is the back-end metal stack.

The klayout-tools SG13CMOS5L deck is young. Part of this canary's job is to
find what it cannot check yet and file those gaps upstream — never to route
around them.

## Inherited from sg13g2-bandgap

`sg13g2-bandgap` is the master for this block by lineage. Its SG13CMOS5L
branch — `spec/porting-plan-sg13cmos5l.md`, decision records 0004 and 0005,
`design/sg13cmos5l/`, the `sim/sg13cmos5l-*` benches and the
`layout/sg13cmos5l-*` cells — is the starting point. It is **pinned**, not
migrated: [`reuse.lock.json`](reuse.lock.json) names the commit
([`0002`](spec/decision-records/0002-sg13g2-bandgap-branch-reuse.md)), so the
block is designed once. Sibling commits read: [`spec/porting-plan.md`](spec/porting-plan.md).

## Target specification (RATIFIED, targets only; see issue #2)

Ratified by [`spec/decision-records/0001-target-spec-ratification.md`](spec/decision-records/0001-target-spec-ratification.md);
binding conditions, planned testbenches, the PVT box, model files and
per-row evidence status are in [`spec/target-spec.md`](spec/target-spec.md).
Port parity: the row shapes mirror `sg13g2-bandgap`'s ratified table; the
values that depend on the bipolar device are derived here, not copied. Every
row below is a *target*, not a result; `spec/target-spec.md`'s Status column
says which rows now have SG13CMOS5L evidence and what it measured. **Nothing
in the table below is edited by a measured result** — a measurement is
evidence against a row, never a new ratified number.

| Parameter | Fallback | Target | Stretch |
|---|---|---|---|
| Output reference | nominal set by the core's TC-null point, untrimmed line only | nominal at the TC-null point; untrimmed line (3σ) from the device-mismatch Monte Carlo on this core; trimmed line with a 1-point trim at 27 °C | tighter trimmed line |
| Trim | none (untrimmed line only) | 1-point @ 27 °C, magnitude only; range and resolution derived from this core's Monte Carlo | — |
| Temp coefficient (−40…125 °C) | < 100 ppm/°C | < 50 ppm/°C | < 20 ppm/°C |
| PSRR @ DC | > 50 dB | > 60 dB | > 70 dB |
| Supply | 3.3 V ±10% (HV devices) | 3.3 V ±10% (HV devices) | 1.2 V (LV devices) |
| Iq | < 100 µA | < 50 µA | < 20 µA |
| Startup | self-starting | self-starting, < 1 ms | — |
| Area | budget set after the first assembled floorplan | budget set after the first assembled floorplan | — |
| Signoff | DRC clean, every LVS gap attributed to a filed klayout-tools issue | DRC + LVS clean | — |

Measured against those targets (all **simulated**, batch fleet, worst case
over the corner grid — see `spec/target-spec.md` for the binding corner and
the cited envelope of each):

| Row | Fallback | Target | Worst measured | Target verdict |
|---|---|---|---|---|
| Temp coefficient, box | < 100 ppm/°C | < 50 ppm/°C | 39.186 ppm/°C | met |
| Temp coefficient, endpoint | < 100 ppm/°C | < 50 ppm/°C | 38.758 ppm/°C | met |
| PSRR @ DC | > 50 dB | > 60 dB | 55.249 dB | **not met** (fallback met) |
| Iq | < 100 µA | < 50 µA | 41.085 µA | met |
| Startup | self-starting | self-starting, < 1 ms | 100 µs, 45/45 self-starting | met |

Still unevidenced: the untrimmed-line (3σ) and trimmed-line accuracy rows and
the Trim row. The first needs the device-mismatch Monte Carlo (issue #31); the
other two need a trim network this design does not have. They are declared
gaps in the T1 item-5 report rather than left out of it.

Maturity ladder: tooling resolved → spec ratified → schematic simulated
across PVT → layout DRC/LVS-clean → post-layout re-verification → shuttle
seat → measured silicon. **Current position: schematic simulated across PVT**
(corner grids only; the statistical rows are not simulated yet).

## Tool flow

- **Design and simulation**: xschem + ngspice, SG13CMOS5L models (installed
  inside a combined IHP-Open-PDK checkout, because the shared device
  symbols and models link to the SG13G2 tree).
- **Layout, DRC, LVS, extraction**: klayout-tools (`klt`).

## Reproduce

Every figure the repo produces is **simulated**, and each record names its
corner and testbench — except the two that are **layout-derived** and labelled
as such: the assembled-top area (`layout/area.json`) and the post-layout
extraction (`sim/pex-bandgap-top/`), both of which come from geometry and deck
coefficients, not from a simulator. All commands run from the repo root; the
full cold start (PDK pin, ngspice, OSDI build) is in
[`sim/README.md`](sim/README.md) and is not repeated here.

- **Smoke bench** (models load and converge, typ / 27 °C / 3.3 V): after the
  cold start, `source sim/env.sh && sim/smoke/run_smoke.sh`.
- **Closed-loop `vref` bench, single corner** (typ / 27 °C / 3.30 V, local):
  `source sim/env.sh && sim/closed-loop-vref-pvt/run.sh`.
  Prerequisites: [`sim/closed-loop-vref-pvt/README.md`](sim/closed-loop-vref-pvt/README.md).
  First measured figure: `vref` = **1.19696 V** (simulated, typ / 27 °C /
  3.30 V, closed loop, settled), record
  `sim/closed-loop-vref-pvt/records/20261113T100202Z-4bfcd8b.json`; it is the
  27 °C point, not the TC-null nominal ([`0009`](spec/decision-records/0009-output-reference-nominal-first-measured.md)).
- **The five PVT grids** (T1 item 5): `source sim/env.sh && sim/grid-run.sh <bench>`
  for each of `closed-loop-vref-pvt`, `closed-loop-vref-pvt-boxtc`,
  `closed-loop-psrr`, `closed-loop-iq`, `closed-loop-startup`. Each submits its
  committed request to the Spot batch fleet and appends a raw `klt sim` envelope
  plus a record. Grids never run as a local `ngspice` loop. What each bench
  grades, and why: [`sim/README.md`](sim/README.md) §PVT grids and each bench's
  own README.
- **Post-layout extraction** (T1 item 7): `source sim/env.sh && sim/pex-run.sh`.
  Runs `klt pex --extract-only` on the committed top GDS at the pinned `klt`
  version and appends an envelope, the extracted netlist and a record. It exits
  **5**, on the device inventory: the curated `sg13cmos5l` extraction deck
  recognises no bipolar, so the extracted netlist is missing all three `pnpMPA`
  devices of the core and **no schematic-vs-extracted delta is producible**.
  What that does and does not establish:
  [`sim/pex-bandgap-top/README.md`](sim/pex-bandgap-top/README.md) and
  [`0012`](spec/decision-records/0012-post-layout-pex-extraction-gap.md).
- **Signoff record** (T1 grading): regenerate it as described in
  [`manifests/README.md`](manifests/README.md).
- **Offline format checks** (no PDK, no network): `bash sim/tests/test-env-pdk-store.sh`,
  `bash sim/tests/test-pex-device-inventory.sh`.

## T1 status

The T1 evidence tier is graded by `klt signoff`, not restated here. The
verdict of record is
[manifests/sg13cmos5l-bandgap.signoff.json](manifests/sg13cmos5l-bandgap.signoff.json);
see [manifests/README.md](manifests/README.md) for how it is regenerated.

Item 5 (full corner verification) is `unmet` / `check_failed`, blocked by two
distinct things the report names separately. Four of the nine declared spec
rows are named **gaps** with no evidence at all. And one row that does have
evidence, `psrr_dc`, **misses its ratified Target** at 24 of its 45 points, so
it is a failed row rather than a covered one. Every other covered row is
**derived** from the envelopes' own `spec_row` tags. The grids are graded at
the ratified Target column throughout; see
[`0011`](spec/decision-records/0011-corner-verification-pvt-grids.md) §2 and §5.

Item 7 (post-layout verification) is `unmet` / `check_failed` on a **cited**
`klt pex` report. The extraction itself is committed and clean — 13 nets with no
`parasitic_integrity` finding, every device body biased — but it holds 17 devices
against the design's 20 cards / 27 units, the whole difference being the core's
three `pnpMPA` devices, which the curated `sg13cmos5l` extraction deck declares
no class for. A delta computed against that netlist would compare two different
circuits, so none is produced and every spec row stays
`insufficient-evidence` **for item 7** (their item-5 evidence is unaffected and
no bound is relaxed). Filed upstream as
[klayout-tools#5477](https://github.com/2AMLogic/klayout-tools/issues/5477) and
[#5479](https://github.com/2AMLogic/klayout-tools/issues/5479); the decision is
[`0012`](spec/decision-records/0012-post-layout-pex-extraction-gap.md).

## Repo layout

```
spec/          ratified spec + decision records + porting plan
design/        schematics / netlists (xschem)
sim/           testbenches + PVT corner results (ngspice)
manifests/     T1 block manifest, vendored checklist, signoff record
layout/        GDS + DRC/LVS reports (klayout-tools driven)
measurements/  silicon characterization (empty until tape-out)
```

## License

Apache License 2.0 — see [LICENSE](LICENSE).

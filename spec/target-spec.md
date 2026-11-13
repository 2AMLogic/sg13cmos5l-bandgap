# Target specification

Ratified by [`0001`](decision-records/0001-target-spec-ratification.md).
Every row is a **target**, not a result. The five closed-loop PVT-grid benches
have now run on the batch fleet and carry T1 item 5's corner verification
([`0011`](decision-records/0011-corner-verification-pvt-grids.md)): seven of
the eleven rows below are measured over the full §PVT grid, four are not. A
measured figure recorded against a row is evidence, never a newly ratified
target number — and **one ratified Target is missed on that evidence** (PSRR
@ DC: **24 of the 45 grid points are below the > 60 dB Target**, worst case
55.249 dB; the > 50 dB Fallback is met at all 45). Every grid is graded at the
ratified Target column ([`0011`](decision-records/0011-corner-verification-pvt-grids.md)
§2), so that miss is a **failing row** in the cited envelope and in
`klt signoff`'s `failed_rows`, not a note under a passing one. It is recorded
as a miss; no bound is edited.

## Table (same as `README.md`)

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

Numbers that read "derived" or "set after" are **not** ratified numbers. The
method and the bench are ratified; the number is recorded by a superseding
decision record when its bench has produced evidence. A number is never
copied from SG13G2 (source `0011` set ±16% on an `npn13G2` core; that does not
transfer to `pnpMPA`).

## Rows in detail

Status values: `target-only` (no bench exists); `partial` (a bench exists but
does not cover the row's binding conditions); `measured, single corner` (a
bench exists, has run, and covers the row's binding conditions, at one corner
only — not a claim about the PVT grid; added by
[`0009`](decision-records/0009-output-reference-nominal-first-measured.md));
`measured, PVT grid` (a bench exists, has run over every point of the row's
binding conditions, and its envelope grades the row at each point; added by
[`0011`](decision-records/0011-corner-verification-pvt-grids.md));
`insufficient-evidence` (the row depends on capacitor corner or mismatch
spread, which the MoM models do not carry).

The **Row id** column is the identifier `manifests/sg13cmos5l-bandgap.json`
declares under `spec_rows.5` and each bench's `klt sim` request tags its graded
measurements with (`measurements[].spec_row`), so `klt signoff` derives item 5's
row coverage from the envelopes rather than from the manifest's assertion. Ids
are stable; a row with two graded figures has two ids. The Area and Signoff rows
have no id: their binding conditions are a layout cell and the DRC/LVS/ERC
decks, which T1 items 2, 3 and 4 grade, not corner verification.

| Row | Row id | Binding conditions | Planned testbench | Monte Carlo | Status |
|---|---|---|---|---|---|
| Output reference, nominal | `vref_nominal` | typ pnpMPA/MOS/res sections, 27 °C, 3.30 V; closed loop with the real amplifier | closed-loop `vref` PVT (`sim/closed-loop-vref-pvt`) | no | `measured, PVT grid` ([`0011`](decision-records/0011-corner-verification-pvt-grids.md)), on top of `measured, single corner` ([`0009`](decision-records/0009-output-reference-nominal-first-measured.md)). The row's binding condition is the single typ/27 °C/3.30 V point, where **SIMULATED** `vref` = **1.19696 V** (testbench `sim/closed-loop-vref-pvt/vref.cir.tmpl`, record `sim/closed-loop-vref-pvt/records/20261113T100202Z-4bfcd8b.json`, ngspice-47, PDK `f7bca32`, `psp103`+`r3_cmc` OSDI; closed loop with the real amplifier, settled: \|vref(2.0 ms) − vref(1.5 ms)\| = 0 V < 1 mV). The whole 45-point grid has now run as well (envelope `sim/closed-loop-vref-pvt/envelopes/20261113T111044Z-3830083.json`, 45/45 pass): `vref` spans **1.18874 V** (`wcs`/2.97 V/125 °C) **… 1.20039 V** (`bcs`/3.63 V/−40 °C), and the bound graded at every point is this bench's own settle criterion (worst 1.03e-8 V < 1 mV), ratified for this bench by [`0009`](decision-records/0009-output-reference-nominal-first-measured.md), because the row's ratified target is the TC-null point — a method, not a number. So this row has **no numeric accuracy target to be graded against**; what the grid establishes is the row's own measured quantity at every point, settled. That is why it stays a covered row rather than a declared gap like `supply`, whose measurement would be the supply value the request itself sets ([`0011`](decision-records/0011-corner-verification-pvt-grids.md) §2). **Not** the TC-null nominal: that needs the temperature sweep of the Temp-coefficient row's bench. The grid span is **not** the ratified untrimmed line, which is a 3σ mismatch figure (next row). Supersedes the source open-loop `vref` 1.2049 V as this row's reference point. |
| Output reference, untrimmed line (3σ) | `vref_untrimmed_line_3sigma` | All 5 process corners × −40/27/125 °C × 2.97/3.30/3.63 V; mismatch MC at each corner point | closed-loop `vref` mismatch MC (new: `sim/closed-loop-vref-mc`) | yes, N ≥ 300/point, seeded, with a zero-spread negative control | `target-only`. |
| Output reference, trimmed line | `vref_trimmed_line` | As above, after a modelled 1-point trim at 27 °C; spread measured over −40…125 °C | trim-domain MC (new, after the trim network exists) | yes | `target-only`. Not stated as a number until measured. |
| Trim | `trim` | 27 °C, all corners and supplies; monotonic; range covers the worst per-die offset from the untrimmed MC | trim-coverage sweep (new, after the trim network exists) | no | `target-only`. A trim is ratified only if the untrimmed MC shows a trimmable offset; if it does not, the Trim row falls back to "none". |
| Temp coefficient | `tc_endpoint`, `tc_box` | −40…125 °C; endpoint method **and** box method both reported; all 5 corners × 3 supplies; closed loop | closed-loop `vref` PVT with 166 temperature points (`sim/closed-loop-vref-pvt-boxtc`) | no | `measured, PVT grid` ([`0011`](decision-records/0011-corner-verification-pvt-grids.md)). 15 units (5 corners × 3 supplies), each a 166-point DC sweep of `TEMP` over −40…125 °C, so both methods reduce inside the unit; envelope `sim/closed-loop-vref-pvt-boxtc/envelopes/20261113T115709Z-0be5a53.json`, 15/15 pass **against the ratified Target bound** (< 50 ppm/°C). **SIMULATED** worst case: box **39.186 ppm/°C**, endpoint **38.758 ppm/°C**, both at `bcs`/3.63 V. Target (< 50) **met**, and so the Fallback (< 100) too; Stretch (< 20) not met. Base-current error term of `pnpMPA` (`bf ≈ 1.10`) is a named line item and is inside both figures. |
| PSRR @ DC | `psrr_dc` | DC, all 5 corners × −40/27/125 °C × 3 supplies; closed loop | closed-loop PSRR (`sim/closed-loop-psrr`) | no | `measured, PVT grid` ([`0011`](decision-records/0011-corner-verification-pvt-grids.md)). 45 points, two DC operating points per point and a 0.1 V supply secant; envelope `sim/closed-loop-psrr/envelopes/20261113T115930Z-0be5a53.json`, graded **against the ratified Target bound** (> 60 dB): **21/45 pass, 24/45 FAIL**. The failing points are every one of the 15 at 2.97 V and 9 of the 15 at 3.30 V; none of the 15 at 3.63 V fails. **SIMULATED** worst case **55.249 dB** at `wcs`/2.97 V/125 °C, best 68.330 dB at `bcs`/3.63 V/27 °C. **Target (> 60 dB) NOT met at more than half the grid**; Fallback (> 50 dB) met at all 45, reported but not graded; Stretch (> 70 dB) not met. This row is therefore a **failed row** of T1 item 5 (`failed_rows: ["psrr_dc"]`), which is what the evidence says: the miss is recorded, not accommodated, and no bound is edited. DC only: no frequency point is specified, and none is simulated. Any future frequency point would depend on MoM/MOS capacitor values and be `insufficient-evidence` until a sensitivity sweep exists. |
| Supply | `supply` | 2.97 / 3.30 / 3.63 V on HV devices; the 1.2 V LV stretch needs an LV-flavour re-derivation of the core and amplifier | every bench above, run on the same supply grid | no | Target met **by construction** (HV device rating, inherited), not by a result. Stretch: `target-only`. Every one of the five item-5 envelopes did run this exact supply axis, so the grid exercised the ratified window; the row is nonetheless declared a **gap** under `spec_rows.5` in `manifests/sg13cmos5l-bandgap.json`, because asserting coverage from a supply value the request itself set would be circular. |
| Iq | `iq` | Assembled, self-biased block; all 5 corners × −40/27/125 °C × 3 supplies; settled | closed-loop Iq (`sim/closed-loop-iq`) | no | `measured, PVT grid` ([`0011`](decision-records/0011-corner-verification-pvt-grids.md)). 45 points, settled; envelope `sim/closed-loop-iq/envelopes/20261113T115819Z-0be5a53.json`, 45/45 pass **against the ratified Target bound** (< 50 µA). **SIMULATED** worst case **41.085 µA** at `bcs`/3.63 V/125 °C, best 19.548 µA. Target (< 50 µA) **met**, and so the Fallback (< 100 µA) too; Stretch (< 20 µA) not met at the worst corner. 'Settled' is graded too: the drift of \|i(Vvdd)\| over the last 0.5 ms is below 1 pA at every point. |
| Startup | `startup_self_starting`, `startup_time` | Release from `vdd` = 0; all 5 corners × −40/27/125 °C × 3 supplies; time to settle inside the band | closed-loop startup (`sim/closed-loop-startup`, decision record 0011); the inherited `sim/sg13cmos5l-closed-loop-startup` and `-pex` at the pin remain the source of the self-starting record and of the only post-layout startup evidence | no | `measured, PVT grid` ([`0011`](decision-records/0011-corner-verification-pvt-grids.md)), superseding `partial`. 45 points; envelope `sim/closed-loop-startup/envelopes/20261113T111658Z-3830083.json`, 45/45 pass. The row's only numeric bound is its Target's `< 1 ms` (the Fallback column carries no time at all), so that is the bound graded here — the same ratified-Target rule the other four benches now follow. The qualitative 'self-starting' both columns share is graded on the source bench's own three criteria: startup released (`v(det)/v(vdd)` ≤ 0.2, worst 0.00890), loop closed (\|sns1 − sns2\| ≤ 20 mV, worst 0.494 mV), `fb` not railed (headroom ≥ 0.05 V, worst 0.701 V). **The `< 1 ms` Target is now extracted**, which the inherited source record 20260829-085039-94869af never did: **SIMULATED** `t_settle_s` = **100 µs** worst case at `wcs`/2.97 V/−40 °C (74 µs best), measured from the release at `vdd` = 0 and so including the 200 µs ramp, to a ±1 % band on the settled `vref`. Source PEX records remain the only post-layout startup evidence. |
| Area | — | Whole `bandgap_top` cell | layout area from the assembled floorplan | no | `target-only`. No budget number is set. Layout-derived footprint of the migrated floorplan: 33 607.5 µm² (`layout/README.md`, decision record 0007); not a budget. |
| Signoff | — | `klt drc`, `klt lvs`, `klt erc` on every cell and on the top | per-cell reports under `layout/` | no | `target-only`. See §Signoff. |

Capacitor rows: the first accuracy budget uses **no** compensation or filter
capacitor (the source core, amplifier and startup have none). If one is added,
every row whose evidence depends on its value (stability margin, any PSRR
frequency point, startup time through the cap) is `insufficient-evidence`, not
a pass, until a capacitor-value sensitivity sweep exists, because the MoM
models carry no corner or mismatch spread.

## PVT

| Axis | Values |
|---|---|
| Process corner labels | `typ`, `bcs`, `wcs`, `sf`, `fs` |
| Temperature | −40, 27, 125 °C |
| Supply | 2.97, 3.30, 3.63 V |
| Points | 5 × 3 × 3 = 45 |

Model files, all under `$PDK_ROOT/ihp-sg13cmos5l/libs.tech/ngspice/models/`
and read from the source testbench template
`sim/sg13cmos5l-core-open-loop-bias/testbench/tb_sg13cmos5l_core_open_loop_bias.spice.tmpl`:

| Device | `.lib` file | Section by corner label |
|---|---|---|
| `pnpMPA` | `cornerPNP.lib` | `typ`→`typ`, `bcs`→`bcs`, `wcs`→`wcs`, `sf`→`typ`, `fs`→`typ` (no skew section exists) |
| HV MOS (`sg13_hv_nmos`, `sg13_hv_pmos`) | `cornerMOShv.lib` | `typ`→`mos_tt`, `bcs`→`mos_ff`, `wcs`→`mos_ss`, `sf`→`mos_sf`, `fs`→`mos_fs` |
| Resistors (`rppd`, `rhigh`) | `cornerRES.lib` | `typ`→`res_typ`, `bcs`→`res_bcs`, `wcs`→`res_wcs`, `sf`→`res_typ`, `fs`→`res_typ` |
| Mismatch (MC) | `sg13cmos5l_pnpMPA_stat.lib` and the MOS/resistor `*_stat` sections, via `cornerPNP.lib` section `stat` | device-mismatch only |

The section names in the table above are **verified at the `dev` pin**
`f7bca32694fe3d58be0cc7d9df4b9f5db7161a14`: `sim/tools/check-model-sections.py`
exits 0 with 12/12 required sections found and 0 problems, so every name
resolves verbatim — no rename. The run (2026-11-13, issue #15), its negative
control and the pin are recorded in `sim/README.md` § "Model section check" and
in `sim/pdk.json` `model_files_verification`. OSDI models used:
`psp103.osdi`, `psp103_nqs.osdi`, `mosvar.osdi`, `r3_cmc.osdi`; all four are
built in the pinned tree, and every bench that has run at the pin preloads
`psp103.osdi` and `r3_cmc.osdi` — the single-corner probe that first recorded
the row ([`0009`](decision-records/0009-output-reference-nominal-first-measured.md))
and all five closed-loop PVT grids
([`0011`](decision-records/0011-corner-verification-pvt-grids.md)), whose
staged-model runs hash-match the pinned libraries on the fleet worker.

The MOS and resistor model files are `sg13g2_*` files shared with the SG13G2
tree, and **how the PDK is installed matters**. In a raw combined IHP-Open-PDK
git checkout they are relative symlinks into `../ihp-sg13g2`, so an
`ihp-sg13cmos5l`-only install cannot resolve them; a fleet PDK store bundle
instead materializes them as real files under `ihp-sg13cmos5l/`. That
materialization is load-bearing, not cosmetic: the store's sibling
`ihp-sg13g2` tree is pinned at **v0.3.0, not at this `dev` pin**, and
`cornerRES.lib`, `sg13g2_moshv_mod.lib` and `resistors_mod.lib` differ in
content between the two trees, so live symlinks on a store-provisioned host
would silently resolve the SG13CMOS5L models to v0.3.0 content.

The Monte Carlo mismatch-section choice is still **open**. The candidates all
exist at the pin — `cornerMOShv.lib` `mos_tt_stat` and `mos_*_mismatch`,
`cornerRES.lib` `res_stat`, `res_stat_mismatch` and `res_*_mismatch` — and
`cornerPNP.lib` `stat` pulls in `sg13cmos5l_pnpMPA_stat.lib` as the table says;
which of the MOS and resistor sections the mismatch benches use is a bench
decision (#31), not settled here.

**Capacitor rows that cannot be cornered:** MoM (`cap_cmomf`, `cap_cmomi`)
carries no corner or mismatch spread. Rows whose evidence depends on a MoM
capacitor value are `insufficient-evidence`. MOS capacitors (`moscap_n/p`) are
cornered through the MOS sections only.

Multi-corner and Monte Carlo grids run as `klt sim` requests (corners,
`monte_carlo`) on the batch fleet, never as local `ngspice` loops. The source
recorded that `klt sim`'s batch backends refused `ihp-sg13cmos5l` at the time
(klayout-tools#2727, #3134 below). **#2727 has since landed** — the batch
image publishes `sg13cmos5l`, so `--backend batch` accepts the variant and the
corner grids of this spec have run ([`0011`](decision-records/0011-corner-verification-pvt-grids.md),
`sim/README.md` §PVT grids). **#3134 was closed as not planned**, so the
`remote` backend still has no CMOS5L image and `batch` is the only off-host
route. The Monte Carlo grids (the untrimmed- and trimmed-line rows) are still
un-run: see issue #31.

The §PVT table above is the grid every item-5 bench runs, with one deliberate
exception. The Temp-coefficient row needs a reduction *across* temperature, and
`klt sim` has no cross-corner reduction, so its bench puts the temperature
sweep **inside** each corner unit (`analysis.kind: "dc"`, `args: "temp -40 125 1"`,
166 points) and runs 5 × 3 = 15 units rather than 45. The temperature axis is
covered more densely, not less; see `sim/closed-loop-vref-pvt-boxtc/README.md`.

## Signoff

DRC and LVS gaps attributed to filed `2AMLogic/klayout-tools` issues, as seen
on 2026-10-17 and re-read on 2026-11-13:

- #2727: batch/remote backends refuse `ihp-sg13cmos5l` (gated every PVT row)
  — **closed, completed**: the batch image publishes `sg13cmos5l`
- #3134: no published CMOS5L batch image (same gate) — **closed, not
  planned**: `remote` has no CMOS5L image, so `batch` is the only off-host route
- #3094: poly resistors in the CMOS5L deck assume coincident GatPoly/PolyRes
  (gates LVS of every `rppd` cell)
- #3739: `klt pex` needs a testbench or measure command to produce an
  extraction-only report (gates post-layout re-verification)
- #5457: a `klt sim` request that selects corners with per-section corner
  libraries has no `models.lib`, so nothing in a batch report can attest the
  models the runner executed (filed while running the item-5 grids). Compounded
  by the batch image's SG13CMOS5L tree publishing no readable PDK revision stamp
  (#5321, #5318). Worked around in this repo with
  `options.stage_model_inputs` (`sim/README.md` → "What the fleet runner cannot
  prove"), which leaves the OSDI binaries unbound.

Not claimed: that this list is complete. Bipolar (`pnpMPA`) recognition in the
CMOS5L LVS deck is a gap the source documents but this plan did not find a
matching open klayout-tools issue for; it is filed or confirmed when the first
layout issue runs LVS.

## Open questions, status after this spec

See [`porting-plan.md`](porting-plan.md) §Open questions.

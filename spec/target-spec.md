# Target specification

Ratified by [`0001`](decision-records/0001-target-spec-ratification.md).
Every row is a **target**, not a result. One SG13CMOS5L accuracy bench has now
run (`sim/closed-loop-vref-pvt`, one corner — see the "Output reference,
nominal" row and
[`0009`](decision-records/0009-output-reference-nominal-first-measured.md));
every other row below is `target-only` or inherits its status from a bench
named in the last column. A measured figure recorded against a row is
evidence, never a newly ratified target number.

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
`insufficient-evidence` (the row depends on capacitor corner or mismatch
spread, which the MoM models do not carry).

| Row | Binding conditions | Planned testbench | Monte Carlo | Status |
|---|---|---|---|---|
| Output reference, nominal | typ pnpMPA/MOS/res sections, 27 °C, 3.30 V; closed loop with the real amplifier | closed-loop `vref` PVT (`sim/closed-loop-vref-pvt`) | no | `measured, single corner` ([`0009`](decision-records/0009-output-reference-nominal-first-measured.md)). **SIMULATED** `vref` = **1.19696 V**, typ/27 °C/3.30 V, closed loop with the real amplifier; testbench `sim/closed-loop-vref-pvt/vref.cir.tmpl`, record `sim/closed-loop-vref-pvt/records/20261113T100202Z-4bfcd8b.json` (ngspice-47, PDK `f7bca32`, `psp103`+`r3_cmc` OSDI), settled: \|vref(2.0 ms) − vref(1.5 ms)\| = 0 V < 1 mV. **Not** the TC-null nominal — that needs the temperature sweep of the Temp-coefficient row's bench, still `target-only`. Supersedes the source open-loop `vref` 1.2049 V as this row's reference point. |
| Output reference, untrimmed line (3σ) | All 5 process corners × −40/27/125 °C × 2.97/3.30/3.63 V; mismatch MC at each corner point | closed-loop `vref` mismatch MC (new: `sim/closed-loop-vref-mc`) | yes, N ≥ 300/point, seeded, with a zero-spread negative control | `target-only`. |
| Output reference, trimmed line | As above, after a modelled 1-point trim at 27 °C; spread measured over −40…125 °C | trim-domain MC (new, after the trim network exists) | yes | `target-only`. Not stated as a number until measured. |
| Trim | 27 °C, all corners and supplies; monotonic; range covers the worst per-die offset from the untrimmed MC | trim-coverage sweep (new, after the trim network exists) | no | `target-only`. A trim is ratified only if the untrimmed MC shows a trimmable offset; if it does not, the Trim row falls back to "none". |
| Temp coefficient | −40…125 °C; endpoint method **and** box method both reported; all 5 corners × 3 supplies; closed loop | closed-loop `vref` PVT with 8 or more temperature points (new: `sim/closed-loop-vref-pvt-boxtc`) | no | `target-only`. Base-current error term of `pnpMPA` (`bf ≈ 1.10`) is a named line item. |
| PSRR @ DC | DC, all 5 corners × −40/27/125 °C × 3 supplies; closed loop | closed-loop PSRR (new: `sim/closed-loop-psrr`) | no | `target-only`. DC only: no frequency point is specified. Any future frequency point would depend on MoM/MOS capacitor values and be `insufficient-evidence` until a sensitivity sweep exists. |
| Supply | 2.97 / 3.30 / 3.63 V on HV devices; the 1.2 V LV stretch needs an LV-flavour re-derivation of the core and amplifier | every bench above, run on the same supply grid | no | Target met **by construction** (HV device rating, inherited), not by a result. Stretch: `target-only`. |
| Iq | Assembled, self-biased block; all 5 corners × −40/27/125 °C × 3 supplies; settled | closed-loop Iq (new: `sim/closed-loop-iq`) | no | `target-only`. |
| Startup | Release from `vdd` = 0; all 5 corners × −40/27/125 °C × 3 supplies; time to settle inside the band | `sim/sg13cmos5l-closed-loop-startup` and `-pex` (inherited bench, source @ pin) | no | `partial`. Source record 20260829-085039-94869af: 45/45 points start (schematic). The `< 1 ms` time was not extracted from that record by this plan; it must be reread before the row is called met. Source PEX records cover startup only. |
| Area | Whole `bandgap_top` cell | layout area from the assembled floorplan | no | `target-only`. No budget number is set. Layout-derived footprint of the migrated floorplan: 33 607.5 µm² (`layout/README.md`, decision record 0007); not a budget. |
| Signoff | `klt drc`, `klt lvs`, `klt erc` on every cell and on the top | per-cell reports under `layout/` | no | `target-only`. See §Signoff. |

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
built in the pinned tree, and the one bench that has run at the pin preloads
`psp103.osdi` and `r3_cmc.osdi` (record
[`0009`](decision-records/0009-output-reference-nominal-first-measured.md)).

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
records that `klt sim`'s batch backends refused `ihp-sg13cmos5l` at the time
(klayout-tools#2727, #3134 below); until those land, no CMOS5L grid has an
authorised execution path. This spec names the grids and does not run them.

## Signoff

DRC and LVS gaps attributed to filed `2AMLogic/klayout-tools` issues, as seen
on 2026-10-17:

- #2727: batch/remote backends refuse `ihp-sg13cmos5l` (gates every PVT row)
- #3134: no published CMOS5L batch image (same gate)
- #3094: poly resistors in the CMOS5L deck assume coincident GatPoly/PolyRes
  (gates LVS of every `rppd` cell)
- #3739: `klt pex` needs a testbench or measure command to produce an
  extraction-only report (gates post-layout re-verification)

Not claimed: that this list is complete. Bipolar (`pnpMPA`) recognition in the
CMOS5L LVS deck is a gap the source documents but this plan did not find a
matching open klayout-tools issue for; it is filed or confirmed when the first
layout issue runs LVS.

## Open questions, status after this spec

See [`porting-plan.md`](porting-plan.md) §Open questions.

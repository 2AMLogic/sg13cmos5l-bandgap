# Porting plan: sg13g2-bandgap SG13CMOS5L branch to this repo

**Status: engineering input.** The decisions it leads to are
[`0001`](decision-records/0001-target-spec-ratification.md) (spec) and
[`0002`](decision-records/0002-sg13g2-bandgap-branch-reuse.md) (reuse).
Written for issue #2, 2026-10-17.

## Sibling commits read

| Repo | Commit (full SHA) | Role |
|---|---|---|
| `2AMLogic/sg13g2-bandgap` | `52535387e6ccf0a89f6490901a9abb2b78144176` (`main`) | **Read for this plan; the pin in `reuse.lock.json`.** |
| `2AMLogic/sg13g2-bandgap` | `e936e1653655197319e5765f6f59aa0da970bb5d` | Commit named when issue #2 was written; 7 commits behind the one above. |

The compare of `e936e16…` to `5253538…` lists only Loom resync files
(`.claude/`, `.agents/`, `.loom/`) and WORK_LOG/WORK_PLAN/README documents.
No design, spec, sim or layout path moved, so the two reads agree.

Paths read at `5253538…`:

- `spec/porting-plan-sg13cmos5l.md`
- decision records `0004-cmos5l-bipolar-device-selection.md`,
  `0005-cmos5l-q2-matched-array-construction.md`,
  `0007-target-spec-ratification.md`,
  `0011-output-reference-row-disposition.md`,
  `0014-trim-row-keep-1-point.md`, and `TEMPLATE.md`
  (the source has no `0012` file; read it as an unused number)
- `design/sg13cmos5l/` (`bandgap_core`, `bandgap_amp`, `bandgap_startup`,
  `bandgap_top`, their netlists and README)
- `sim/sg13cmos5l-*`: `core-open-loop-bias`, `startup-trip-point`,
  `closed-loop-startup`, `closed-loop-startup-pex`; and `sim/pdk-sg13cmos5l.json`
- `layout/sg13cmos5l-bandgap_{amp,core,startup,top}`
- the ratified SG13G2 README table (Output reference, Trim, TC, PSRR, Supply,
  Iq, Startup rows)

The PDK, not a sibling repo, is read at the pin in
`sim/pdk-sg13cmos5l.json` of the source: `IHP-GmbH/IHP-Open-PDK` branch `dev`
@ `f7bca32694fe3d58be0cc7d9df4b9f5db7161a14`, subtree `ihp-sg13cmos5l/`. The
source records that this repo's existing evidence was generated on the
archived standalone `IHP-GmbH/ihp-sg13cmos5l` @
`607e18d4bd9214a52575c194b4181ef449f9252f`, and that nothing has been
simulated at the `dev` pin. This repo's own pin is issue #4's job.

## Inherit unchanged (cited, not re-argued)

- 3.3 V HV supply flavour (source DR-0002, carried by DR-0004).
- `rppd` precision resistor and its ≥ 2 µm line width on ratio-critical legs.
- The `pnpMPA` device reading (`.subckt pnpMPA c b e`, `bf = 1.10*sgp_mpa_bf`,
  electrical area dependence through `a` only; source DR-0004, DR-0005).
- Grounded-collector `pnpMPA` core, three legs, Q2 as 8 parallel unit devices
  (`m=8`) (source DR-0004, DR-0005).
- The decision-record process, the evidence conventions and the friction
  protocol.
- The row shapes: untrimmed / trimmed / trim rows (source DR-0007, 0011, 0014).
  Row **shapes** are inherited; SG13G2 row **values** are not.

## Re-derive on SG13CMOS5L

| Item | Why it cannot be copied | Evidence in the source at the pin |
|---|---|---|
| TC-null nominal output and the R-ratio behind it | Source SG13G2 landed 1.050 V on an `npn13G2` core; this core sums `VEB(pnpMPA)` | Open-loop only: `vref` 1.2049 V at typ/27 °C/3.30 V, closed-loop startup `vref_final` ≈ 1.197 V at typ/−40 °C. No TC bench. |
| Untrimmed line (3σ) | Source's ±16% is an `npn13G2` mismatch result | None. No device-mismatch Monte Carlo exists for this core. |
| Base-current error budget | `pnpMPA` gain is near 1 (`bf ≈ 1.10`) | None. |
| Compensation and filter capacitors | No MIM; MoM and MOS caps only; MoM models carry no corner or mismatch spread | None. Source first pass has no compensation cap. |
| PSRR, DC | Source has no PSRR bench on this core | None. |
| TC | Source has no TC bench on this core | None. |
| Iq of the assembled, self-biased block | Source has no Iq bench on this core | None. |
| Trim network, if ratified | Source trim ladder is sized for the `npn13G2` core's scatter | None. |
| Post-layout re-verification | Source PEX evidence is startup only | `closed-loop-startup-pex` only. |

## Corner box and model files (for the spec)

Named in `target-spec.md` §PVT. Taken from the source's
`sim/sg13cmos5l-core-open-loop-bias` testbench template and
`sim/lib/pvt_preflight.sh`; the model files come from the PDK at the pin
(directory `libs.tech/ngspice/models/`).

## Open questions and how this plan answers them

1. **Near-unity `pnpMPA` gain vs the TC target.** Open. The source gives no
   TC evidence. `target-spec.md` keeps the TC row at the SG13G2 numbers as a
   target and marks it `target-only` until a TC bench exists. The base-current
   term is a named line item of the first accuracy budget.
2. **klt SG13CMOS5L deck gaps.** The open `2AMLogic/klayout-tools` issues
   found while scoping (listed in `target-spec.md` §Signoff) already cover the
   gaps seen here. No new issue was filed; see the PR description.
3. **PDK release and OSDI models.** Open, awaiting #4. The source records that
   the old standalone pin shipped prebuilt `.osdi` binaries and the `dev` pin
   does not (upstream removed prebuilt `cap_cmomi`/`cap_cmomf`; models are built
   from Verilog-A). Not verified at the `dev` pin by anyone yet.
4. **All-MOS reference if `pnpMPA` fails the TC target.** Recorded as a
   **different block**, not a fallback of this one: it would change the
   topology, the device reading and every row's evidence. It needs its own
   issue and decision record if the TC fallback (< 100 ppm/°C) is also
   missed. Recorded in `0001`.

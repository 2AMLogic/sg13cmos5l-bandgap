# 0009: Record the first measured closed-loop `vref`; move "Output reference, nominal" off `target-only`

- **Status**: ratified, effective when the PR for issue #19 merges
- **Date**: 2026-11-13
- **Decided by**: Loom Builder agent, issue #19

## Context

`spec/target-spec.md` ratified every accuracy row as a **target**, with the
"Output reference, nominal" row at `target-only`: its binding conditions are
"typ pnpMPA/MOS/res sections, 27 °C, 3.30 V; closed loop with the real
amplifier", and no bench in this repo had ever produced a figure under them.
`sim/closed-loop-vref-pvt/` (issue #14, PR #18) was written as that bench but
had never been executed — its author had no host with the pinned PDK, so its
README said "Not verified here" and `records/` held only `.gitkeep`. Issue #19
owed the first run.

The pinned PDK now reaches fleet hosts through the fleet PDK store (operator
ruling 2026-10-24; `sim/env.sh` learned the `.pdk-store.json` marker in issue
#21), so the run became possible: `~/share/pdk` reports
`f7bca32694fe3d58be0cc7d9df4b9f5db7161a14`, the `sim/pdk.json` pin, with
ngspice-47 and all six OSDI objects present.

The first run did not simulate the DUT at all. `klt sim` composes its own top
deck (title `* klt sim -- generated corner deck, do not edit`) and pulls the
bench deck in with `.include`, so the bench deck's line 1 is **not** in SPICE
title position — it is parsed as a netlist element. `vref.cir.tmpl` carried a
bare title line `sg13cmos5l closed-loop vref bench`, which ngspice read as an
`S`-prefix (voltage-controlled switch) instance with no model and killed the
run with "Unable to find definition of model" before any analysis started
(`analysis_started: false`). `sim/smoke/smoke.cir`, the bench that already
worked, has a `*` comment on line 1 and so was never exposed to this.

## Decision

- **Fix the deck-composition defect in this repo's bench, not the DUT.**
  `vref.cir.tmpl` line 1 becomes a comment and `run.sh` writes two leading
  `*` lines into the generated deck, so the deck handed to `klt sim` carries
  no SPICE title line whether it is `.include`d or read directly. The fetched
  DUT netlist, its pin and the `.end`-stripping transformation are untouched.
  This is the "unless trivial" runner fix issue #19 allowed; it changes no
  gate, exit code or record field.
- **Move "Output reference, nominal" off `target-only`** to a new status,
  `measured, single corner`, carrying the simulated figure with its label,
  corner, testbench and record file. The row's binding conditions are
  satisfied exactly: typ sections, 27 °C, 3.30 V, closed loop with the real
  amplifier.
- **Add `measured, single corner` to the status vocabulary** of
  §"Rows in detail": a bench exists, has run, and covers the row's binding
  conditions, at one corner only. It is not a claim about the PVT grid.
- **The figure is not the TC-null nominal.** The ratified Target column asks
  for "nominal at the TC-null point"; finding that point needs a temperature
  sweep, which is the Temp-coefficient row's bench
  (`sim/closed-loop-vref-pvt-boxtc`, still `target-only`). The row states the
  27 °C/3.30 V typ point and says so.
- **No target number is relaxed or ratified from this.** The measured value is
  evidence attached to a row, not a new ratified spec number; the Target
  column is unchanged.

## Alternatives considered

- **Commit the failure record and file the deck fix as a separate issue.**
  Rejected: the failure was a two-line title-line defect in this repo's own
  template, not a circuit, PDK or model finding, so the "non-convergence is a
  finding" clause did not apply. It would have delivered no `vref` figure and
  left issue #30's T1 chain blocked for another cycle. The failure record is
  committed anyway (below), so nothing is hidden.
- **Call the row met / `partial`.** Rejected both ways. "Met" overstates one
  corner against a row whose Target is the TC-null nominal; `partial` is
  defined as "a bench exists but does **not** cover the row's binding
  conditions", which is now false.
- **Also update §PVT's "not verified at the `dev` pin" note** on the model
  sections and OSDI names. Rejected as out of scope: issue #15 owns that
  question. The evidence found here (all 12 required sections resolve at the
  pin, `psp103`/`r3_cmc` load) is reported to #15 instead.
- **Edit the DUT netlist to help it converge.** Never considered: the netlist
  is a pinned byte-for-byte migration (record 0006) and converged untouched.

## Consequences

- `spec/target-spec.md` has its first evidence-backed accuracy row. Every
  other accuracy row stays `target-only`.
- `sim/closed-loop-vref-pvt/records/` holds the first three records of this
  bench, append-only: one `status: failed` record from the pre-fix run (whose
  `template_sha256` is the pre-fix template, and whose `klt_envelope` carries
  the `ngspice_fatal` diagnostic), and two `status: ok` records that agree at
  `vref` = 1.19696 V, showing the measurement is reproducible run to run.
- The bench's README no longer says it is unverified.
- Re-running the bench **appends** a record rather than exiting 4: the
  append-only guard in `cm5_record_path` keys on
  `<UTC-second>-<short sha>.json`, so exit 4 only fires on a same-second,
  same-commit collision. Prior records were verified byte-identical across a
  re-run. Issue #19's acceptance criterion expected exit 4 from any second
  run; that expectation does not match the runner, and the discrepancy is
  reported on the issue rather than papered over.
- The remaining 44 points of `request-45pt.json` are still un-run, so the
  untrimmed-line, TC and PSRR rows are unaffected.

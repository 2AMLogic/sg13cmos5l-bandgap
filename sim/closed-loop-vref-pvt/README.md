# closed-loop-vref-pvt

First closed-loop `vref` bench (issue #14, part of #5). It is the planned bench behind the
"Output reference, nominal" row of `spec/target-spec.md`. Every figure is **simulated**.

| File | Role |
|---|---|
| `run.sh` | Runner: one `klt sim --backend local` unit at typ / 27 °C / 3.30 V, writes one record |
| `vref.cir.tmpl` | Deck template: supply, substrate tie, OSDI preload, include of the fetched DUT |
| `request-45pt.json` | The full §PVT grid (5 process × 3 temperature × 3 supply = 45). **Committed, never run here** |
| `records/` | Append-only JSON records (`<UTC>-<short sha>.json`) |

## Run

```bash
source sim/env.sh && sim/closed-loop-vref-pvt/run.sh
```

Prerequisites are those of the smoke bench (`sim/README.md` 'Cold start'), plus `gh` with read
access to `2AMLogic/sg13g2-bandgap`, and both `psp103.osdi` and `r3_cmc.osdi` built (`rppd`/`rhigh`
need `r3_cmc`). Exit codes: 0 record with `vref_v`; 3 missing prerequisite; 4 record exists;
5 simulation failed (a record with `status: failed` and `failure_reason` is written); 6 source
fetch or pin refused (named `SOURCE_UNREACHABLE` / `SOURCE_COMMIT_MISMATCH`, no record).

## What is fetched, not copied

`design/sg13cmos5l/netlist/bandgap_top.spice` is read at run time from the commit pinned in
`reuse.lock.json` (decision record 0002). The runner resolves that commit through the forge and
refuses unless it equals the pinned 40-hex. The file is a flattened xschem export, not a
`.subckt bandgap_top`: bare instances `Xx1`/`Xx2`/`Xx3` on nets `vdd vss vref fb sns1 sns2`, then
`bandgap_core`, `bandgap_amp`, `bandgap_startup` subckts, no `.lib`/`.include`. The deck therefore
drives `vdd`/`vss`, ties the `sub!` bulk net to `vss`, and supplies the model `.lib`s. The only
change to the fetched text is dropping its final `.end` card; `source_file_sha256` in each record
is the hash of the file as fetched.

## Record

Fields: `pdk_revision` (equals `sim/pdk.json` `revision`, enforced by `sim/env.sh`),
`source_commit`, `deck_sha256`, `corner`, `vref_v`, plus `label: SIMULATED`, `testbench`,
`settle_criterion`, simulator versions and the `klt` envelope. `vref_v` is read at 2.0 ms of a
2 ms transient from DC sources; it is accepted only if `|vref(2.0 ms) − vref(1.5 ms)| < 1 mV`.

## Non-convergence is a finding

If the fetched netlist does not converge or settle at the `dev` pin, the runner writes a record
with `status: failed`, no `vref_v` and the reason, and exits 5. The source netlist is not edited.
`cornerRES.lib res_typ` is the §PVT-table name and is not exercised by the smoke bench; if it does
not resolve at this pin the failure is recorded here and cross-referenced to #15.

## The 45-point grid is un-run

`request-45pt.json` is committed so the grid is reviewable, and it is **not executed**. Host rules
forbid a local grid and the batch backends refuse `ihp-sg13cmos5l` until klayout-tools#2727 and
#3134 land. The request uses a DC `Vvdd` so `klt` can alter it for the supply axis; its absolute
`netlist`/`models.lib` paths point at the runner's generated files under `sim/build/`, and the
deck's `pre_osdi` paths are host-local, so a batch run needs both addressed first.

## Not verified here

This bench was written on a host without the pinned PDK or OSDI objects, so `run.sh` has not been
executed; only the request file and shell syntax were checked. The first record is still owed.

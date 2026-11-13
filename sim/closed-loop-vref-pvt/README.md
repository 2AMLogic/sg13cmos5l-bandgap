# closed-loop-vref-pvt

First closed-loop `vref` bench (issue #14, part of #5). It is the planned bench behind the
"Output reference, nominal" row of `spec/target-spec.md`. Every figure is **simulated**.

| File | Role |
|---|---|
| `run.sh` | Runner: one `klt sim --backend local` unit at typ / 27 °C / 3.30 V, writes one record |
| `vref.cir.tmpl` | Deck template: supply, substrate tie, OSDI preload, include of the in-repo DUT netlist |
| `request-45pt.json` | The full §PVT grid (5 process × 3 temperature × 3 supply = 45). **Committed, never run here** |
| `records/` | Append-only JSON records (`<UTC>-<short sha>.json`) |

## Run

```bash
source sim/env.sh && sim/closed-loop-vref-pvt/run.sh
```

Prerequisites are those of the smoke bench (`sim/README.md` 'Cold start'), plus both `psp103.osdi` and `r3_cmc.osdi` built (`rppd`/`rhigh`
need `r3_cmc`). Exit codes: 0 record with `vref_v`; 3 missing prerequisite; 4 record exists;
5 simulation failed (a record with `status: failed` and `failure_reason` is written); 6 source
netlist missing or pin unreadable (named `SOURCE_MISSING`, no record).

## Where the DUT comes from

`design/sg13cmos5l/netlist/bandgap_top.spice` is the in-repo copy migrated byte-for-byte from
`2AMLogic/sg13g2-bandgap` at the commit in `reuse.lock.json` (decision record 0006, which amends
0002 for these cells); the runner reads it, no forge access. The file is a flattened xschem export, not a
`.subckt bandgap_top`: bare instances `Xx1`/`Xx2`/`Xx3` on nets `vdd vss vref fb sns1 sns2`, then
`bandgap_core`, `bandgap_amp`, `bandgap_startup` subckts, no `.lib`/`.include`. The deck therefore
drives `vdd`/`vss`, ties the `sub!` bulk net to `vss`, and supplies the model `.lib`s. The only
change to the fetched text is dropping its final `.end` card; `source_file_sha256` in each record
is the hash of the file as read (equal to the pinned source blob).

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

`run.sh` narrows the request to one corner (typ/27 C/3.30 V) and also lowers `timeout_s` from 600 to 300.

## The 45-point grid is un-run

`request-45pt.json` is committed so the grid is reviewable, and it is **not executed**. Host rules
forbid a local grid and the batch backends refuse `ihp-sg13cmos5l` until klayout-tools#2727 and
#3134 land. The request uses a DC `Vvdd` so `klt` can alter it for the supply axis; its absolute
`netlist`/`models.lib` paths point at the runner's generated files under `sim/build/`, and the
`options.osdi_preload` paths (written by `run.sh` from `CM5_OSDI_DIR`, as the smoke bench does; no
`.control` block in the deck) are host-local, so a batch run needs both addressed first.

## First run (issue #19)

Run on a fleet host whose `~/share/pdk` carries the pinned PDK through the fleet PDK store
(`.pdk-store.json` version `f7bca32…`), ngspice-47, all six OSDI objects built:

**`vref` = 1.19696 V, SIMULATED, typ / 27 °C / 3.30 V, closed loop**, settled
(`|vref(2.0 ms) − vref(1.5 ms)|` = 0 V < 1 mV). Record
`records/20261113T100202Z-4bfcd8b.json`; the figure moved the "Output reference, nominal" row of
`spec/target-spec.md` off `target-only` (decision record 0009). It is the 27 °C/3.30 V typ point,
**not** the TC-null nominal.

`records/` is append-only and holds three records from that session:

| Record | Status | What it shows |
|---|---|---|
| `20261113T095937Z-4bfcd8b.json` | `failed` | The pre-fix run. `klt sim` `.include`s this bench's deck into a top deck of its own, so the deck's former SPICE title line was parsed as an `S`-prefix switch instance with no model: `ngspice_fatal` "Unable to find definition of model", `analysis_started: false`. Its `template_sha256` is the pre-fix template. Fixed in the same change (0009) by removing the title line. |
| `20261113T100202Z-4bfcd8b.json` | `ok` | First measured `vref`, the figure cited in the spec row. |
| `20261113T100302Z-4bfcd8b.json` | `ok` | A re-run, same `vref` to all recorded digits: the measurement is reproducible, and the prior records were byte-identical afterwards. |

**A second run appends, it does not exit 4.** `cm5_record_path`'s append-only guard keys on
`<UTC second>-<short sha>.json`, so exit 4 only fires on a same-second, same-commit collision;
any later run writes a new record and exits 0 (or 5). Existing records are never overwritten.

Still un-run: the 45-point grid and the mismatch MC (see above). Observed but not acted on here:
ngspice warns `Unknown model type pspnqs103va - ignored` for the `*_psp_rf` model variants the
PDK's `sg13g2_moshv_mod.lib` defines, because this bench preloads `psp103.osdi` and `r3_cmc.osdi`
but not `psp103_nqs.osdi`. No device in the DUT instantiates an RF variant, so the warnings are
inert; a bench that needs one must add that preload.

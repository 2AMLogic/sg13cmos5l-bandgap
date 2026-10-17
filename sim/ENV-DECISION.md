# Decision: own `sim/env.sh`, adopted OSDI builder (issue #4)

**Status**: accepted 2026-10-17. Source read: `2AMLogic/sg13g2-bandgap` at
`66f9d846130fc6f06ecaa24b1021c3304496f6b9` (`sim/env.sh`, `sim/tools/build-osdi.sh`,
`sim/pdk-sg13cmos5l.json`). `sg13g2-lna` was not read.

## What was decided

| Piece | Outcome | Why |
|---|---|---|
| PDK pin value | **Adopted** from `sim/pdk-sg13cmos5l.json`: IHP-Open-PDK `dev` @ `f7bca32694fe3d58be0cc7d9df4b9f5db7161a14` | Designed once. That repo had never run anything on this pin (its file says "runtime compatibility is UNVERIFIED"); `sim/smoke/records/` is the first run. |
| `sim/env.sh` | **Own**, not adopted | The source resolver defaults `PDK=ihp-sg13g2`, only *warns* when no install is found, and has no revision check, so the acceptance criterion "refuses on a mismatch" cannot be met by it. Wrapping it would still need its search order duplicated to read the revision. The search order is kept identical; the PDK name comes from `sim/pdk.json`. A change to the source (a revision check) would be a request on that repo, not something to wait for here. |
| OSDI builder | **Adopted by pin** (`reuse.lock.json`, `sim/tools/build-osdi.sh` @ the commit above), fetched not copied | It builds `psp103`, `psp103_nqs`, `r3_cmc`, `mosvar` from the PDK's own Verilog-A with a checksum-pinned `openvaf-r`. It works unchanged with `PDK=ihp-sg13cmos5l` in a combined checkout (shown by the smoke record). |

## Findings that bear on the source or on #2 (evidence, not spec decisions)

1. No IHP-Open-PDK release tag ships `ihp-sg13cmos5l` (`v0.3.0` has none); only `dev`.
2. `openvaf-r` v24.0.1mob emits OSDI **v0.4**. Ubuntu 24.04's `ngspice-42` accepts v0.3 only
   and fails with `NGSPICE only supports OSDI v0.3 ... targets v0.4`, then
   `could not find a valid modelname` for every MOS. `ngspice-46` loads them. The source's
   `build-osdi.sh --check` does not state a minimum ngspice version.
3. `build-osdi.sh` does not build `cap_cmomi.osdi` / `cap_cmomf.osdi`, which the PDK's
   `.spiceinit` loads for the MoM capacitors. No bench here needs them yet.
4. The source's `build-osdi.sh --check` prints `OK` on its own check deck against SG13CMOS5L, so
   its hard-coded `cornerMOShv.lib` / `cornerRES.lib` paths work there via the symlinks.

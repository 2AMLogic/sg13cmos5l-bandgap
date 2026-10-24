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

## 2026-10-24: fleet PDK store marker accepted as revision proof (issue #21)

Operator ruling (rjwalters, attended fleet:decide round 20261024-r1, PDK question option 1): the
pinned PDK reaches fleet hosts through the fleet PDK store, not a hand copy. A store tree has no
`.git` and no `.pdk-revision`; it carries `$PDK_ROOT/ihp-sg13cmos5l/.pdk-store.json`
(`{name, version, sha256, synced, bucket, key}`, per 2am `infra/aws/pdk-store.md`).

`sim/env.sh` now tries `.pdk-revision`, then git HEAD, then that marker (last resort, so existing
paths are unchanged). It requires `name == ihp-sg13cmos5l` and `version == sim/pdk.json revision`;
named refusals are `PDK_STORE_VERSION_MISMATCH` (states found and pinned versions),
`PDK_STORE_NAME_MISMATCH` and `PDK_STORE_MARKER_UNREADABLE`. The pin does not change. The marker's
`sha256` is not checked. Not verified here: that the store writes `version` as the full 40-hex
commit (2am `scripts/lib/pdk_store.py` was not available on this host); the check is an exact
string match, so a short form or tag would be refused with `PDK_STORE_VERSION_MISMATCH`.
Test: `sim/tests/test-env-pdk-store.sh`.

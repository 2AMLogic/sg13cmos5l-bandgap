# sim

Simulation environment for the SG13CMOS5L bandgap. Today this holds only the
PDK pin, a bring-up smoke bench (issue #4, T1 item 9) and the first design bench, closed-loop `vref` (issue #14).

| File | Role |
|---|---|
| `pdk.json` | The pin: IHP-Open-PDK `dev` @ `f7bca326…`, model files, OSDI objects, minimum ngspice |
| `env.sh` | Sourced; resolves `PDK_ROOT`/`PDK`, **refuses** unless the install is the pinned revision |
| `smoke/` | `.op`-style smoke deck (one `sg13_hv_nmos`, one `pnpMPA`, typ/27 °C/3.3 V), runner, append-only `records/` |
| `closed-loop-vref-pvt/` | Closed-loop `vref` bench (typ/27 °C/3.30 V run, 45-point request committed un-run), fetches the DUT at the `reuse.lock.json` pin |
| `runner-lib.sh`, `tools/cm5_record.py` | Shared by the bench runners: tool/ngspice gates, append-only record path and write, klt-envelope value extraction (record 0008) |
| `ENV-DECISION.md` | Why `env.sh` is this repo's own and the OSDI builder is adopted by pin |

Every figure these produce is **simulated**. The smoke circuit is not part of the
design and proves only that the models load and converge.

## Prerequisites

- `git`, `python3`, `curl`, `dpkg-deb`, `sha256sum`, `klt` (klayout-tools).
- **ngspice ≥ 43.** Ubuntu 24.04's apt `ngspice-42` cannot load the OSDI objects (see
  `ENV-DECISION.md`, finding 2). Observed good: ngspice 46.
- Network access for the steps below. Nothing is installed host-wide; everything goes
  under `sim/build/` (gitignored).

## Cold start

All commands from the repo root.

**Fleet route.** On a fleet host the pinned PDK arrives through the fleet PDK store (2AMLogic/2am
`infra/aws/pdk-store.md`), not a hand copy, so step 1 is skipped. The store tree has no `.git` and
no `.pdk-revision`; `sim/env.sh` accepts its `$PDK_ROOT/ihp-sg13cmos5l/.pdk-store.json` marker when
`name` is `ihp-sg13cmos5l` and `version` equals the pin. Check it with
`bash sim/tests/test-env-pdk-store.sh` (fake trees, no real PDK needed).

```bash
# 1. PDK: a combined checkout at the pinned commit (ihp-sg13cmos5l/ needs the ihp-sg13g2/ sibling).
mkdir -p sim/build && git init -q sim/build/IHP-Open-PDK
git -C sim/build/IHP-Open-PDK fetch --depth 1 https://github.com/IHP-GmbH/IHP-Open-PDK f7bca32694fe3d58be0cc7d9df4b9f5db7161a14
git -C sim/build/IHP-Open-PDK checkout -q FETCH_HEAD

# 2. ngspice >= 43 (skip if `ngspice --version` already says 43 or newer).
#    ngspice-46.tar.gz sha256 (as computed on download) a0d1699af1940b06649276dcd6ff5a566c8c0cad01b2f7b5e99dedbb4d64c19b
(cd sim/build &&
  curl -fsSLO https://downloads.sourceforge.net/project/ngspice/ng-spice-rework/old-releases/46/ngspice-46.tar.gz &&
  tar -xzf ngspice-46.tar.gz && mkdir -p ngspice-obj && cd ngspice-obj &&
  ../ngspice-46/configure --prefix="$PWD/../ngspice-46-install" --with-x=no --disable-debug --enable-osdi --enable-klu=no &&
  make -j2 && make install)
export PATH="$PWD/sim/build/ngspice-46-install/bin:$PATH"

# 3. OSDI build (below), then:
source sim/env.sh              # prints the resolved paths, or a named error
sim/smoke/run_smoke.sh         # one `klt sim --backend local` unit; writes sim/smoke/records/<utc>-<sha>.json
```

### OSDI build

The PDK ships Verilog-A sources but no `.osdi`. Build them with the adopted builder,
pinned in `reuse.lock.json` (`sg13g2-bandgap@66f9d846…`, `sim/tools/build-osdi.sh`):

```bash
git clone -q https://github.com/2AMLogic/sg13g2-bandgap sim/build/sg13g2-bandgap
git -C sim/build/sg13g2-bandgap checkout -q 66f9d846130fc6f06ecaa24b1021c3304496f6b9
export PDK_ROOT="$PWD/sim/build/IHP-Open-PDK" PDK=ihp-sg13cmos5l SG13G2_TOOLS_CACHE="$PWD/sim/build/cache"
sim/build/sg13g2-bandgap/sim/tools/build-osdi.sh        # checksum-verified openvaf-r + libLLVM 21
```

Output lands in `$PDK_ROOT/ihp-sg13cmos5l/libs.tech/ngspice/osdi/` (`psp103`, `psp103_nqs`,
`r3_cmc`, `mosvar`). `cap_cmomi` / `cap_cmomf` are **not** built by it; no bench here needs them yet.

## Refusals

`source sim/env.sh` returns 1 with one of: `PDK_NOT_FOUND`, `SIBLING_MISSING` (no `ihp-sg13g2/`
next to `ihp-sg13cmos5l/`, so shared-model symlinks dangle), `REVISION_UNKNOWN`,
`PDK_REVISION_MISMATCH` (`installed <sha> at <path>, sim/pdk.json pins <sha>`).
Search order for `PDK_ROOT`: `$PDK_ROOT`, `sim/build/IHP-Open-PDK`, `/usr/share/pdk`,
`/usr/local/share/pdk`, `~/share/pdk`, `~/.ciel`, `~/.volare`.

## Records

`sim/smoke/records/*.json` are append-only: `run_smoke.sh` creates a new file per run and
refuses to overwrite one. Each states the simulator version, PDK revision, deck sha256,
corner and testbench, and embeds the `klt sim` envelope.

## Model section check

`source sim/env.sh && python3 -I sim/tools/check-model-sections.py` statically parses
`cornerPNP.lib`, `cornerMOShv.lib` and `cornerRES.lib` and checks that every section
`spec/target-spec.md` §PVT names exists (plus `cornerPNP.lib` `stat`), naming the defining
file and the `.include` targets it resolves to. Exit 0 = all present, 1 = a section or include
is missing (or a symlink dangles), 2 = no models directory. `--models-dir` overrides
`$CM5_NGSPICE_MODELS`. Mismatch candidates (`mos_*_stat`, `mos_*_mismatch`, `res_stat`,
`res_*_mismatch`) are listed as informational only.

Offline exit-code test (fake models tree, no PDK needed): `bash sim/tests/test-model-sections.sh`.

Finding (**at the pin**, 2026-11-13, issue #15): run against `PDK_ROOT=~/share/pdk`
delivered by the fleet PDK store, whose `ihp-sg13cmos5l/.pdk-store.json` reports version
`f7bca32694fe3d58be0cc7d9df4b9f5db7161a14` so `sim/env.sh` accepts it (#21), the tool exits 0
with **12/12 required sections found, 0 problems**. Every section name `spec/target-spec.md`
§PVT writes resolves verbatim — `cornerPNP.lib` `typ`/`bcs`/`wcs`/`stat`, `cornerMOShv.lib`
`mos_tt`/`mos_ff`/`mos_ss`/`mos_sf`/`mos_fs`, `cornerRES.lib` `res_typ`/`res_bcs`/`res_wcs` —
so **no rename, and the spec text needs no decision record**. `stat` pulls in
`sg13cmos5l_pnpMPA_stat.lib` as the spec says. Negative control at the pin: the same
`cornerPNP.lib` copied to a scratch directory with its `.LIB stat` block deleted, then
`--models-dir` at that copy, exits 1 with `ERROR: cornerPNP.lib section 'stat' not defined`
(11/12). `sim/smoke/run_smoke.sh` passes at the pin on ngspice-47 — record
`sim/smoke/records/20261113T095737Z-66c149b.json`.

All mismatch candidates exist too (`cornerMOShv.lib` `mos_tt_stat` and `mos_*_mismatch`;
`cornerRES.lib` `res_stat`, `res_stat_mismatch`, `res_*_mismatch`) but stay informational:
which of them the Monte Carlo benches use is deliberately **not** decided here.

Second finding — **the store bundle materializes the shared files, and that matters.** An
upstream combined git checkout at this pin carries the SG13G2-shared models as relative
symlinks into `../ihp-sg13g2` (`pdk.json` `variant_of_checkout`); the store bundle ships them
as real files, so every `model_files` entry now reads `real_file: true` and the checker's
`defined_in` stays inside `ihp-sg13cmos5l/`. This is load-bearing rather than cosmetic: the
store's sibling `ihp-sg13g2` tree is pinned at **v0.3.0, not at this dev commit**, and
`cornerRES.lib`, `sg13g2_moshv_mod.lib` and `resistors_mod.lib` differ in content between the
two trees. Live symlinks on this host would therefore resolve the SG13CMOS5L models to v0.3.0
content while `env.sh` still reported the `f7bca32` pin. Materialized copies are what keep the
models at the pin. A host that installs a raw combined git checkout instead will see these as
symlinks (`real_file: false`) into whatever revision its own `ihp-sg13g2` holds, so the
`real_file` column describes the install, not the PDK.

`spec/target-spec.md` §PVT still carries its pre-verification caveat ("not verified at the
`dev` pin") and its unqualified symlink statement; retiring both needs a decision record, so
it is tracked in #62 rather than edited here.

## Item 9 attestation

`attest/item9.json` inventories the shipped benches and the documented cold start for T1 item 9;
`evidence/item9.json` is the committed `klt signoff --attest 9` envelope. See `attest/README.md`.

# sim

Simulation environment for the SG13CMOS5L bandgap. Today this holds only the
PDK pin and a bring-up smoke bench (issue #4, T1 item 9); no design bench yet.

| File | Role |
|---|---|
| `pdk.json` | The pin: IHP-Open-PDK `dev` @ `f7bca326…`, model files, OSDI objects, minimum ngspice |
| `env.sh` | Sourced; resolves `PDK_ROOT`/`PDK`, **refuses** unless the install is the pinned revision |
| `smoke/` | `.op`-style smoke deck (one `sg13_hv_nmos`, one `pnpMPA`, typ/27 °C/3.3 V), runner, append-only `records/` |
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

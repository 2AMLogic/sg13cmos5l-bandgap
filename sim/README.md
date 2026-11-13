# sim

Simulation environment for the SG13CMOS5L bandgap: the PDK pin, a bring-up smoke bench
(issue #4, T1 item 9), the five PVT-grid benches that carry T1 item 5's corner
verification (issue #30), and the post-layout extraction that carries T1 item 7 (issue #32).

| File | Role |
|---|---|
| `pdk.json` | The pin: IHP-Open-PDK `dev` @ `f7bca326…`, model files, OSDI objects, minimum ngspice |
| `env.sh` | Sourced; resolves `PDK_ROOT`/`PDK`, **refuses** unless the install is the pinned revision |
| `smoke/` | `.op`-style smoke deck (one `sg13_hv_nmos`, one `pnpMPA`, typ/27 °C/3.3 V), runner, append-only `records/` |
| `closed-loop-vref-pvt/` | Closed-loop `vref`: the Output-reference-nominal row. 45 points; also keeps `run.sh`, the single-corner local probe behind decision record 0009 |
| `closed-loop-vref-pvt-boxtc/` | Closed-loop `vref` over temperature: the Temp-coefficient row, endpoint **and** box method. 15 units, each a 166-point DC sweep of `TEMP` |
| `closed-loop-psrr/` | PSRR @ DC: two DC solves per point and a 0.1 V supply secant. 45 points |
| `closed-loop-iq/` | Quiescent supply current, settled. 45 points |
| `closed-loop-startup/` | Release from `vdd` = 0: self-starting **and** the settling time the inherited source bench never extracted. 45 points |
| `grid-run.sh` | The one runner for all five grids: stages the migrated DUT, renders the deck, submits the committed request to the batch fleet, writes the envelope and the record |
| `pex-bandgap-top/` | T1 item 7 (post-layout verification): the committed `klt pex --extract-only` envelope, the extracted netlist, and the schematic-vs-extracted device inventory. **No delta** — see below |
| `pex-run.sh`, `tools/pex_device_inventory.py` | The item-7 runner and the offline device-inventory comparator it embeds in each record |
| `runner-lib.sh`, `tools/cm5_record.py` | Shared by the bench runners: tool/ngspice gates, append-only record path and write, klt-envelope value extraction and grid reduction (record 0008, extended by 0011) |
| `ENV-DECISION.md` | Why `env.sh` is this repo's own and the OSDI builder is adopted by pin |

## PVT grids: one runner, the batch fleet, and what it can and cannot prove

Run one grid:

```bash
source sim/env.sh && sim/grid-run.sh closed-loop-psrr      # or any of the five bench directory names
```

Each bench directory carries `bench.json` (the graded criteria and which files to use), a
deck template, and a committed `request-grid.json` (`request-45pt.json` in
`closed-loop-vref-pvt`, whose name decision record 0009 already cites). `grid-run.sh` writes
two artifacts per run, both append-only:

- `envelopes/<UTC>-<short sha>.json` — the raw `klt sim --format json` envelope. **This is the
  artifact `manifests/sg13cmos5l-bandgap.json` cites for T1 item 5**; `klt signoff` reads it.
- `records/<UTC>-<short sha>.json` — this repo's own record: the PDK and source pins, the DUT,
  deck, template and request hashes, the per-row verdict with its binding corner, and the name
  of the envelope beside it.

**Grids go to the Spot batch fleet, never to a local `ngspice` loop.** That is the host rule
for any multi-corner request; `grid-run.sh` passes `--wait-for-capacity 600` so a vCPU-budget
refusal waits with backoff instead of failing the step, and a failed submit is recorded and
reported rather than worked around locally. A single corner may still run locally — that is
what `closed-loop-vref-pvt/run.sh` is. `$CM5_GRID_BACKEND` overrides the backend for a
non-dispatch host an operator names.

Every committed request is **host-portable**: `models.pdk` plus PDK-relative per-section corner
libraries (no generated corner bundle, no absolute host path, which `batch` refuses),
`$PDK_ROOT/...` OSDI entries the runner resolves on its own box, and
`options.stage_model_inputs: true`.

### What the fleet runner cannot prove (and what staging fixes)

The batch image bakes a SG13CMOS5L tree under `/opt/pdk`, but that tree publishes **no readable
revision stamp**: a grid run with models resolved on the runner comes back with
`worker_environment.pdk.stamp_text: null`, a `pdk stamp unreadable: FileNotFoundError`
diagnostic, `pdk_stamp_comparison.status: "not_comparable"` and a null
`remote.runner_models_lib_sha256`. Nothing in such an envelope ties the models that ran to
`sim/pdk.json`'s pinned revision — the record's `pdk_revision` would only be a statement about
the submitting host.

`options.stage_model_inputs: true` closes most of that: it uploads this host's pinned corner
libraries **and their whole `.include`/`.lib` closure** with the job (15 files for these
benches) and reports their sha256 twice — `environment.staged_model_inputs` as the client sent
them and `remote.runner_model_inputs` as the worker received them. Both lists match in every
committed envelope here, so the model text behind each figure is bound to the pin by hash.

**Residual gap, stated rather than closed**: the OSDI compact-model binaries are the image's,
not the pin's. They are declared as literal `$PDK_ROOT/...`, so they are runner-resolved, not
staged and not hashed. Staging them would need a host-absolute `osdi_preload` path, which would
make every request unportable and uncommittable, so the gap is instead **bounded by
measurement** — and that measurement is reproducible, not just described:

```bash
source sim/env.sh && CM5_GRID_NO_STAGE=1 sim/grid-run.sh closed-loop-vref-pvt
```

turns staging off and writes its artifacts with an `.image-models` suffix, so the same grid
against the fleet image's own PDK tree can be compared value for value with the staged run.
`closed-loop-vref-pvt/envelopes/` holds both:

| Envelope | Models | Job |
|---|---|---|
| `20261113T112115Z-3830083.image-models.json` | resolved on the runner from the fleet image | `klt-sim-eb3c80bdefd3` |
| `20261113T111044Z-3830083.json` | staged from this host's pin (15 files, hashes matched by the worker) | `klt-sim-fbbab809f5c5` |

All **315** measurements (45 points × 7) agree exactly. The image's SG13CMOS5L models and this
pin's are therefore behaviourally identical for these sections — measured, not assumed.
`manifests/` cites the staged envelope, because only that one binds the models to the pin by
hash.

The tool-side half of the gap is filed as generic friction at
[`2AMLogic/klayout-tools#5457`](https://github.com/2AMLogic/klayout-tools/issues/5457): a
request that selects corners with per-section corner libraries has **no** `models.lib`, so
`environment.models_lib_sha256` is null by construction and the runner-side comparison #5321
added (`remote.models_lib_comparison`) can only ever report `runner_hash_unavailable` — the
portable multi-family request shape is the one shape whose executed models cannot be attested.
The unreadable image stamp itself is `klayout-tools#5321`/`#5318`, already filed.

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
corner and testbench, and embeds the `klt sim` envelope. The grid benches' `records/` and
`envelopes/` are append-only on the same terms (`cm5_record_path` refuses an existing path, and
`write_record` opens with `"x"`); a second run in the same UTC second at the same commit is the
only case that collides, and it exits 4 rather than overwriting.

## Model section check

`source sim/env.sh && python3 -I sim/tools/check-model-sections.py` statically parses
`cornerPNP.lib`, `cornerMOShv.lib` and `cornerRES.lib` and checks that every section
`spec/target-spec.md` §PVT names exists (plus `cornerPNP.lib` `stat`), naming the defining
file and the `.include` targets it resolves to. Exit 0 = all present, 1 = a section or include
is missing (or a symlink dangles), 2 = no models directory. `--models-dir` overrides
`$CM5_NGSPICE_MODELS`. Mismatch candidates (`mos_*_stat`, `mos_*_mismatch`, `res_stat`,
`res_*_mismatch`) are listed as informational only.

Offline exit-code test (fake models tree, no PDK needed): `bash sim/tests/test-model-sections.sh`.

## Post-layout extraction (T1 item 7): what is committed, and what is not producible

```bash
source sim/env.sh && sim/pex-run.sh
```

One `klt pex --extract-only` run of `layout/sg13cmos5l-bandgap_top/sg13cmos5l-bandgap_top.gds`
at the `klt` 0.8.0 pin, writing three append-only artifacts under `pex-bandgap-top/`
(`envelopes/`, `extracted/`, `records/`) on the same terms as the grid benches. Item 7 cites
the envelope; the record quotes `extraction.model` and `body_bias` verbatim and embeds the
device inventory.

**The schematic-vs-extracted delta item 7 actually wants is not producible**, and the runner
exits 5 saying so. The curated `sg13cmos5l` extraction deck declares no bipolar device class
(`klt deck devices --deck sg13cmos5l`: `nfet`, `pfet`, `cap_cmomi`, `cap_cmomf`, `rsil`,
`rppd`, `rhigh`), so the bandgap core's three `pnpMPA` devices are not recognised and are
**absent** from the extracted netlist: 17 devices against the design's 20 cards / 27 units,
every MOS and both poly-resistor flavours matching card-for-card and the entire difference
being the bipolar. `tools/pex_device_inventory.py` measures that from the two committed
netlists (no PDK, no klt, no network) and `tests/test-pex-device-inventory.sh` re-derives it
on every CI run. An extracted leg simulated on that netlist would converge and report
numbers, so the 45-point grids are deliberately **not** re-run against it.

The device-recognition gap is upstream and already ruled out of scope there
(klayout-tools#4927: the PDK's own runset recognises `pnpMPA` and `klt lvs` with `"engine":
"klayout-runset"` in its request is the supported path, but `klt extract`/`klt pex` have no
engine selector at all). Filed
as generic friction: [`klayout-tools#5477`](https://github.com/2AMLogic/klayout-tools/issues/5477)
(no coverage disclosure for a deck's missing device class, and no runset route for
extraction) and [`#5479`](https://github.com/2AMLogic/klayout-tools/issues/5479) (an
extraction-only citation renders item 7 `check_failed` with `citation: null`). Full account:
[`pex-bandgap-top/README.md`](pex-bandgap-top/README.md) and decision record
[`0012`](../spec/decision-records/0012-post-layout-pex-extraction-gap.md).

Nothing in `pex-bandgap-top/` is simulated: it is **layout-derived** — geometry out of the
committed GDS, R/C out of the deck's own coefficients.

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

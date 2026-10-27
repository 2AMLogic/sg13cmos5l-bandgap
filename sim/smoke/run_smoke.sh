#!/usr/bin/env bash
# sg13cmos5l-bandgap -- PDK smoke bench runner (issue #4). Cold-start:
#
#   source sim/env.sh && sim/smoke/run_smoke.sh      # see sim/README.md for prerequisites
#
# One corner (typ / 27 C / 3.3 V), one `klt sim --backend local` unit. Writes
#   sim/smoke/records/<UTC timestamp>-<short git sha>.json
# and never overwrites an existing record (append-only evidence). Scratch goes
# to sim/build/smoke/ (gitignored). The figures are SIMULATED.
set -euo pipefail

SMOKE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SIM_DIR="$(cd "${SMOKE_DIR}/.." && pwd)"
REPO_DIR="$(cd "${SIM_DIR}/.." && pwd)"

# shellcheck source=../env.sh
source "${SIM_DIR}/env.sh" || { echo "run_smoke.sh: sim/env.sh refused; see the error above." >&2; exit 3; }

# shellcheck source=../runner-lib.sh
source "${SIM_DIR}/runner-lib.sh"
cm5_gate run_smoke.sh ngspice klt python3 sha256sum
cm5_osdi_gate run_smoke.sh psp103
OSDI="${CM5_OSDI_DIR}/psp103.osdi"

WORK="${SIM_DIR}/build/smoke"
rm -rf "${WORK}"; mkdir -p "${WORK}"
DECK="${WORK}/deck.cir"
BUNDLE="${WORK}/corners.lib"   # klt selects the `typ` section by the request's process label
{
  echo ".lib typ"
  echo ".lib \"${CM5_NGSPICE_MODELS}/cornerPNP.lib\" typ"
  echo ".lib \"${CM5_NGSPICE_MODELS}/cornerMOShv.lib\" mos_tt"
  echo ".endl typ"
} > "${BUNDLE}"
grep -v '^\*' "${SMOKE_DIR}/smoke.cir" > "${DECK}"

cat > "${WORK}/request.json" <<EOF
{
  "engine": "ngspice",
  "netlist": "${DECK}",
  "netlist_source": "extracted",
  "models": { "lib": "${BUNDLE}" },
  "corners": { "process": ["typ"], "supply_v": { "Vdd": [3.3] }, "temperature_c": [27] },
  "analysis": { "kind": "tran", "args": "10n 50n" },
  "measurements": [
    { "name": "v_drain_v", "spice": ".meas tran v_drain_v find v(d) at=40n" },
    { "name": "v_emitter_v", "spice": ".meas tran v_emitter_v find v(e) at=40n" },
    { "name": "i_vdd_a", "spice": ".meas tran i_vdd_a find i(Vdd) at=40n" }
  ],
  "options": { "timeout_s": 120, "keep_artifacts": true, "osdi_preload": ["${OSDI}"] }
}
EOF

# ngspice has no .MEASURE OP, so the DC operating point is a short transient with
# only DC sources, read at 40 ns. -o keeps klt's envelope; its exit status is the gate.
klt sim --backend local --format json -o "${WORK}/out" "${WORK}/request.json" > "${WORK}/envelope.json"

cm5_record_path run_smoke.sh "${REPO_DIR}" "${SMOKE_DIR}/records"

python3 -I - "${WORK}/envelope.json" "${REC}" "${DECK}" "${SMOKE_DIR}/smoke.cir" "${NGSPICE_VERSION}" \
  "${CM5_PDK_REVISION}" "${SHA}" "${STAMP}" "${SIM_DIR}/pdk.json" "${SIM_DIR}/tools" <<'PY'
import json, sys
env_p, rec_p, deck_p, src_p, ngspice, pdk_rev, sha, stamp, pin_p, tools_dir = sys.argv[1:]
sys.path.insert(0, tools_dir)
from cm5_record import collect, klt_version as get_klt_version, sha256, write_record
envelope = json.load(open(env_p))
pin = json.load(open(pin_p))
klt_version = get_klt_version()

values = collect(envelope, ("v_drain_v", "v_emitter_v", "i_vdd_a"))
if set(values) != {"v_drain_v", "v_emitter_v", "i_vdd_a"}:
    sys.exit("run_smoke.sh: klt envelope has no value for every measurement; refusing to write a record. Found: %r" % values)

record = {
    "kind": "pdk-smoke",
    "label": "SIMULATED",
    "testbench": "sim/smoke/smoke.cir",
    "corner": {"process": "typ", "vdd_v": 3.3, "temperature_c": 27},
    "timestamp_utc": stamp,
    "repo_git_sha": sha,
    "pdk": {"name": pin["pdk"], "revision": pdk_rev, "pin_file": "sim/pdk.json"},
    "simulator": {"ngspice": ngspice, "klt": klt_version, "backend": "local"},
    "deck_sha256": sha256(deck_p),
    "source_deck_sha256": sha256(src_p),
    "osdi_preload": ["psp103.osdi"],
    "measurements": values,
    "klt_envelope": envelope,
}
write_record(rec_p, record)
print("run_smoke.sh: wrote", rec_p)
for k, v in values.items():
    print("  %s = %.6g (simulated, typ/27C/3.3V)" % (k, v))
PY
